package Nazar::FIFO;
use strict;
# For such a simple object, moose is way overkill. just use a state hash
# use Moose;
use AnyEvent;
use AnyEvent::Util qw(guard);
use namespace::clean -except => qw(meta);

sub new {
    my $class = shift;
    my $args  = (ref $_[0] eq 'HASH') ? $_[0] : {@_};
    return bless {
        queue => [],
        active => 0,
        max_active => $args->{max_active} || 1,
    }
}

sub drain {
    my $self = shift;
    my $queue = $self->{queue};
warn "drain";
    while (scalar (@$queue) > 0 && $self->{active} < $self->{max_active}) {
        warn "checking queue...";
        if (my $cb = shift @{$self->{queue}}) {
            $self->{active}++;
            $cb->( AnyEvent::Util::guard {
                $self->{active}--;
                $self->drain();
            } );
        }
    }
}

sub push {
    my ($self, $next) = @_;
    push @{ $self->{queue} }, $next;
    $self->drain();
}

1;

__END__