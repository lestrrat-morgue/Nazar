package Nazar;
use Moose;
use AnyEvent;
use namespace::autoclean;

has watchers => (
    traits => ['Array'],
    is => 'ro',
    isa => 'ArrayRef[Nazar::Watcher]',
    lazy_build => 1,
    handles => {
        all_watchers => 'elements',
    }
);

has queues => (
    traits => ['Hash'],
    is => 'ro',
    isa => 'HashRef[Nazar::Queue]',
    handles => {
        queue_get => 'get',
        queue_set => 'set',
    }
);

sub start {
    my $self = shift;
    foreach my $watcher ( $self->all_watchers ) {
        $watcher->set_context($self);
        $watcher->start( $self );
    }
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

Nazar - The Evil Eye Watches Over You

=head1 SYNOPSIS

    my $n = Nazar->new();
    $n->register_queue( MyQueue->new() );
    $n->start;

=head1 DESCRIPTION

Nazar is an asynchronous framework to run smoke tests

=cut
