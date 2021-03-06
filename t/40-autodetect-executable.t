#! perl

use strict;
use warnings;

use Test::More 0.89;

use Config;
use ExtUtils::Builder::AutoDetect::C;
use ExtUtils::Embed qw/ldopts/;
use IPC::Open2 qw/open2/;
use File::Basename qw/basename dirname/;
use File::Spec::Functions qw/catfile/;

# TEST does not like extraneous output
my $quiet = $ENV{PERL_CORE} && !$ENV{HARNESS_ACTIVE};

sub capturex {
	local @ENV{qw/PATH IFS CDPATH ENV BASH_ENV/};
	my $pid = open2(my($in, $out), @_);
	binmode $in, ':crlf' if $^O eq 'MSWin32';
	my $ret = do { local $/; <$in> };
	waitpid $pid, 0;
	return $ret;
}

my $b = ExtUtils::Builder::AutoDetect::C->new;
my $c = $b->get_compiler(profile => '@Perl', type => 'executable');

my $source_file = catfile('t', 'executable.c');
{
	open my $fh, '>', $source_file or die "Can't create $source_file: $!";
	my $content = <<END;
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"

static PerlInterpreter* my_perl;

#line 33
int main(int argc, char **argv, char **env) {
	PERL_SYS_INIT3(&argc,&argv,&env);
	my_perl = perl_alloc();
	perl_construct(my_perl);
	PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
	perl_parse(my_perl, NULL, argc, argv, env);
	perl_run(my_perl);
	perl_destruct(my_perl);
	perl_free(my_perl);
	PERL_SYS_TERM();
	return 0;
}
END
	print $fh $content or die "Can't write to $source_file: $!";
	close $fh or die "Can't close $source_file: $!";
}

ok(-e $source_file, "source file '$source_file' created");

my $object_file = catfile(dirname($source_file), basename($source_file, '.c') . $Config{obj_ext});

$c->compile($source_file, $object_file)->execute(logger => \&note, quiet => $quiet);

ok(-e $object_file, "object file $object_file has been created");

my $exe_file = catfile(dirname($source_file), basename($object_file, $Config{obj_ext}) . $Config{exe_ext});

my $l = $b->get_linker(profile => '@Perl', type => 'executable');
ok($l, "get_linker");

$l->link([$object_file], $exe_file)->execute(logger => \&note, quiet => $quiet);

ok(-e $exe_file, "lib file $exe_file has been created");

my $output = eval { capturex($exe_file, '-e', "print 'Dubrovnik\n'") };

is ($output, "Dubrovnik\n", 'Output is "Dubrovnik"') or diag("Error: $@");

END {
	for ($source_file, $object_file, $exe_file) {
		next if not defined;
		1 while unlink;
	}
	if ($^O eq 'VMS') {
		1 while unlink 'EXECUTABLE.LIS';
		1 while unlink 'EXECUTABLE.OPT';
	}
}

done_testing;

