package ExtUtils::Builder::Linker::PE::GCC;

use strict;
use warnings;

use base qw/ExtUtils::Builder::Role::Linker::Unixy ExtUtils::Builder::Role::Linker::COFF/;

use File::Basename ();

sub _init {
	my ($self, %args) = @_;
	$args{ld} ||= ['gcc'];
	$self->ExtUtils::Builder::Role::Linker::Unixy::_init(%args);
	$self->ExtUtils::Builder::Role::Linker::COFF::_init(%args);
	return;
}

sub linker_flags {
	my ($self, $from, $to, %opts) = @_;
	my @ret = $self->SUPER::linker_flags($from, $to, %opts);

	push @ret, $self->new_argument(ranking => 85, value => ['-Wl,--enable-auto-image-base']);
	if ($self->type eq 'shared-library' or $self->type eq 'loadable-object') {
		push @ret, $self->new_argument(ranking => 10, value => ['--shared']);
	}
	if ($self->autoimport) {
		push @ret, $self->new_argument(ranking => 85, value => ['-Wl,--enable-auto-import']);
	}

	if ($self->export eq 'all') {
		push @ret, $self->new_arguments(ranking => 85, value => ['-Wl,--export-all-symbols']);
	}
	elsif ($self->export eq 'some') {
		my $export_file = $opts{export_file} || ($opts{basename} || File::Basename::basename($to)) . '.def';
		push @ret, $self->new_argument(ranking => 20, value => [$export_file]);
	}
	return @ret;
}

1;
