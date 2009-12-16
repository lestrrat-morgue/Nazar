package Nazar::Queue::CPAN;
use Moose;
use AnyEvent::HTTP;
use File::Copy qw(copy);
use File::Temp ();
use MooseX::Types::Path::Class;
use Nazar::FIFO;
use Scalar::Util qw(weaken);
use URI::Escape qw(uri_escape);
use namespace::autoclean;

extends 'Nazar::Queue';

has fifo => (
    is => 'ro',
    isa => 'Nazar::FIFO',
    lazy_build => 1,
);

has build_dir => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    coerce => 1,
    lazy_build => 1,
);

has download_dir => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    coerce => 1,
    lazy_build => 1,
);

has max_active => (
    is => 'ro',
    isa => 'Int',
    default => 10
);

has perl => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    default => $^X
);

has work_dir => (
    is => 'ro',
#    isa => 'File::Temp::Dir',
    lazy_build => 1,
);

sub item_push {
    my ($self, $item) = @_;

    # we'll receive a hash of "stuff", but what we really want is a closure
    my $closure = sub {
        my $guard = shift;

            
        my $output_log = $self->build_dir->file("$item->{dist}-$item->{version}-output.log");
        my $pid = fork();
        if (! defined $pid) {
            confess "Could not fork";
        }

        if (! $pid) {
            # I want a completely separate process, so I'm spawning this
            print "Testing $item->{dist}\n";

            my $smoke_pl = File::Spec->catfile($self->work_dir, 'smoke.pl');
            open(my $fh, '>', $smoke_pl) or confess "Could not open $smoke_pl: $!";

            # download the file
            require LWP::UserAgent;
            require CPAN::Inject;
            require CPAN;

            my $work_dir     = $self->work_dir;
            my $build_dir    = $self->build_dir->stringify;
            my $download_dir = $self->download_dir->stringify;
warn $build_dir;
            CPAN::HandleConfig->load() and $CPAN::Config_loaded++;
            local $CPAN::Config->{ build_dir }         = $build_dir;
            local $CPAN::Config->{ cpan_home }         = $work_dir;
            local $CPAN::Config->{ keep_source_where } = $download_dir;

            my $local = $self->download_dir->file("$item->{dist}-$item->{version}.tar.gz")->stringify;

            # if the item is a local file, just copy it over
            my $install;
            if ($item->{file} && -f $item->{file}) {
                print "Copying $item->{file}...\n";
                copy( $item->{file}, $local ) or
                    confess "Could not copy $item->{file} to $local: $!";
                $install = CPAN::Inject->from_cpan_config->add( file => $local );
            } else {
                print "Downloading $item->{uri}... ";
                my $res = LWP::UserAgent->new->mirror( $item->{uri}, $local );
                if ($res->is_error) {
                    print "failed\n";
                    $install = $item->{dist};
                } else {
                    print "success\n";
                    $install = CPAN::Inject->from_cpan_config->add( file => $local );
                }
            }

            # Where should I handle smoke reports? (if this were /just/ a
            # CPAN smoker, it would be in the CPAN test process itself...)
            print $fh (<<'            EOPL');
                use strict;
                use File::Spec;
                use CPAN;

                my($install, $work_dir, $build_dir, $download_dir, $output_log) = @ARGV;
                open STDIN, '<', File::Spec->devnull;
                open STDOUT, '>', $output_log
                    or die "Failed to open output.log: $!";
                open STDERR, '>&', STDOUT
                    or die "Failed to dup STDOUT to STDERR: $!";

                CPAN::HandleConfig->load() and $CPAN::Config_loaded++;
                local $CPAN::Config->{ build_dir }         = $build_dir;
                local $CPAN::Config->{ cpan_home }         = $work_dir;
                local $CPAN::Config->{ keep_source_where } = $download_dir;
                local $CPAN::Config->{ histfile }          = File::Spec->catfile( $work_dir, 'histfile' );
                local $CPAN::Config->{ prefsdir }          = File::Spec->catfile( $work_dir, 'prefs');
                local $CPAN::Config->{ prerequisites_policy } = 'follow';

                # XXX close STDIN?

                CPAN::Shell->test($install);
            EOPL
            close($fh);
            exec( $self->perl, $smoke_pl, $install, $work_dir, $build_dir, $download_dir, $output_log);
            exit 1;
        } else {
            my $w; $w = AE::child $pid => sub {
                undef $guard;
                undef $w;

                # XXX Somehow get a handle to the email queue

                print STDERR "\n\n\n>>>>>>>> REAPED $pid: $item->{dist} <<<<<<<\n\n\n";
                weaken($self);
                weaken($item);
            };
        }
    };

    $self->fifo->push($closure);
};

sub _build_fifo { Nazar::FIFO->new(max_active => $_[0]->max_active) }
sub _build_build_dir { Path::Class::Dir->new($_[0]->work_dir, 'build') }
sub _build_download_dir { Path::Class::Dir->new($_[0]->work_dir, 'download') }
sub _build_work_dir { File::Temp::tempdir(CLEANUP => 1, TEMPDIR => 1, ) }

sub BUILD {
    my $self = shift;
    $self->download_dir->mkpath or die;
    $self->build_dir->mkpath or die;
    return $self;
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

