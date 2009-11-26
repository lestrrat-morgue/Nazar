package Nazar::Watcher;
use Moose;
use namespace::clean -except => qw(meta);

has context => (
    is => 'ro',
    isa => 'Nazar',
    writer => 'set_context',
);

__PACKAGE__->meta->make_immutable();

1;
