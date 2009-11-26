package Nazar::Watcher::CPAN;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Nazar::Watcher';

__PACKAGE__->meta->make_immutable();

1;