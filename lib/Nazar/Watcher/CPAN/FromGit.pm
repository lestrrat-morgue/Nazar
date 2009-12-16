
package Nazar::Watcher::CPAN::FromGit;
use Moose;
use AnyEvent::MP qw(configure port rcv *SELF $NODE);
use AnyEvent::MP::Global qw(grp_reg);
use Cwd;
use File::Temp qw(tempdir);
use POSIX qw(strftime);
use namespace::autoclean;

extends 'Nazar::Watcher::CPAN';

has perl => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    default => $^X
);

has git => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    lazy_build => 1,
);

has make => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    lazy_build => 1,
);


sub _build_make { _find_cmd('make') }
sub _build_git { _find_cmd('git') }
sub _find_cmd { 
    my $cmd = shift;
    my @paths = split(/:/, $ENV{PATH});
    if (! @paths) {
        @paths = qw(/opt/local/bin /usr/local/bin /usr/bin /bin);
    }

    foreach my $path (@paths) {
        my $x = File::Spec->catfile($path, $cmd);
        if (-x $x) { return $x }
    }
}

sub start {
    my $self = shift;

    configure nodeid => 'nazar/'; #  profile => $self->profile;
    grp_reg 'nazar', $NODE;

    rcv $NODE, gitcommit => sub {
        my ($repo, $sha1, $dist, $version) = @_;
        my $w; $w = AE::idle sub { 
            undef $w;
            $self->run_test($repo, $sha1, $dist, $version);
        }
    };
}

sub run_test {
    my ($self, $repo, $sha1, $dist, $version) = @_;

    $version ||= POSIX::strftime('%Y%m%d%H%M%S', localtime);
    eval {
        my $tempdir = tempdir(CLEANUP => 1, TEMPDIR => 1);
        my $git_dir = File::Spec->catfile($tempdir, "$dist-$version");

        system($self->git, 'clone', $repo, $git_dir) == 0 or die;

        my $file;
        {
            my $cwd = cwd();
            my $guard = AnyEvent::Util::guard { chdir $cwd };
            chdir $git_dir;
            system($self->perl, 'Makefile.PL') == 0 or die;
            if (! -f 'MANIFEST') {
                system($self->make, 'manifest') == 0 or die;
            }
            system($self->make, 'dist');
            while (glob('*.tar.gz')) {
                $file = File::Spec->catfile($git_dir, $_) and last;
            }
        }

        if (! $dist) {
            if ($repo =~ /:\/([^:]+)\.git/) {
                $dist = $1;
            }
        }
        if (! $version) {
            $version = strftime('%Y%m%d%H%M%S', localtime);
        }

        my %data = ( 
            file => $file,
            sha1 => $sha1,
            repo => $repo,
            dist => $dist,
            version => $version,
            tempdir => $tempdir, # keep it in memory
        );
        $self->context->queue_get( "CPAN" )->item_push( \%data );
    };
    if ($@) {
        warn $@;
    }
}

1;

__END__

Receive an update form git commit
expect the repo to contain CPAN style dist
inject to CPAN