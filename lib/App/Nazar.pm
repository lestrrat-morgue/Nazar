package App::Nazar;
use Moose;
use Nazar;
use namespace::clean -except => qw(meta);

with qw(MooseX::Getopt MooseX::SimpleConfig);

has config => (
    is => 'ro',
    isa => 'HashRef',
);

sub run {
    my $self = shift;

    my $config = $self->config;

    my $instantiate = sub {
        my ($prefix, $config) = @_;
        my $class = delete $config->{class};
        if ($class !~ s/^\+//) {
            $class = "${prefix}::${class}";
        }
        
        if (! Class::MOP::is_class_loaded($class)) {
            Class::MOP::load_class( $class );
        }
        return $class->new(%$config);
    };
    my @watchers;
    foreach my $watcher (@{ $config->{watchers} || die "no watchers defined" }) {
        push @watchers, $instantiate->("Nazar::Watcher", $watcher);
    }
    my %queues;
    while ( my ($name, $queue) = each %{ $config->{queues} || die "no queues defined" }) {
        $queues{$name} = $instantiate->("Nazar::Queue", $queue);
    }

    my $cv = AnyEvent->condvar;
    local %SIG;
    foreach my $sig qw(INT TERM HUP QUIT) {
        $SIG{$sig} = sub {
            $cv->send;
        };
    }
    my $nazar = Nazar->new(
        watchers => \@watchers,
        queues   => \%queues,
    );
    $nazar->start;

    $cv->recv;
}

1;
