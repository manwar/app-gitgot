#! perl

use autodie;
use strict;
use warnings;

use Test::File;
use Test::MockObject;
use Test::More;

BEGIN {
  my $mock = Test::MockObject->new();
  $mock->fake_module(
    'Net::GitHub::V2::Repositories' ,
    'fork' => sub { 1 } ,
  );
  $mock->fake_new( 'Net::GitHub::V2::Repositories' );
  $mock->mock( fork => sub { 1 } );
}

use App::Cmd::Tester;
use App::GitGot;
use Cwd               qw/ abs_path /;
use File::Temp        qw/ tempdir /;
use YAML              qw/ LoadFile /;

my $dir    = tempdir(CLEANUP=>1);
chdir $dir;
my $config = abs_path( "$dir/gitgot" );
file_not_exists_ok $config , 'config does not exist';

$ENV{HOME} = $dir;

{
  my $result = test_app( 'App::GitGot' => [ 'fork' , '-f' , $config ]);
  is $result->stdout , '' , 'nothing on STDOUT';
  like $result->stderr ,
    qr/ERROR: Need the URL of a repo to fork/ ,
    'need to give a URL';
  is $result->exit_code , 1 , 'exit with 1';
  file_not_exists_ok $config , 'failed command does not create config';
}

{
  my $result = test_app( 'App::GitGot' => [ 'fork' , '-f' , $config , 'http://not.github.org/' ]);
  is $result->stdout , '' , 'nothing on STDOUT';
  like $result->stderr ,
    qr|ERROR: Can't find .*\.github-identity| ,
      'need ~/.github-identity';
  is $result->exit_code , 1 , 'exit with 1';
  file_not_exists_ok $config , 'failed command does not create config';
}

open( my $OUT , '>' , '.github-identity' );
print $OUT <<EOF;
login luser
token my-user-token-thingie
EOF
close( $OUT );

{
  my $result = test_app( 'App::GitGot' => [ 'fork' , '-f' , $config , 'http://not.github.org/' ]);
  is $result->stdout , '' , 'nothing on STDOUT';
  like $result->stderr ,
    qr|ERROR: Can't parse 'http://not.github.org| ,
      'need to give a *github* URL';
  is $result->exit_code , 1 , 'exit with 1';
  file_not_exists_ok $config , 'failed command does not create config';
}

{
  my $result = test_app( 'App::GitGot' => [ 'fork' , '-f' , $config ,
                                            'http://github.com/genehack/fake-git-repo.git' ]);

  is $result->stdout    , '' , 'no output';
  is $result->stderr    , '' , 'nothing on STDERR';
  is $result->exit_code , 0  , 'exit with 0';

  file_exists_ok $config , 'now config exists';

  my $entry = LoadFile( $config );
  is( $entry->[0]{name} , 'fake-git-repo'                  , 'expected name' );
  is( $entry->[0]{type} , 'git'                            , 'expected type' );
  is( $entry->[0]{path} , abs_path( "$dir/fake-git-repo" ) , 'expected path' );
}

done_testing();
