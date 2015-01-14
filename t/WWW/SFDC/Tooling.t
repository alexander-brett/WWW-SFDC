use 5.12.0;
use strict;
use warnings;

use Data::Dumper;
use Test::More;
use Config::Properties;

use_ok "WWW::SFDC::Tooling";


SKIP: { #only execute if creds provided

  my $options = Config::Properties
    ->new(file => "t/test.config")
    ->splitToTree() if -e "t/test.config";

  skip "No test credentials found in t/test.config", 1
    unless $options->{username}
    and $options->{password}
    and $options->{url};

  ok my $res = WWW::SFDC::Tooling->instance(
    username => $options->{username},
    password => $options->{password},
    url => $options->{url}
   )->executeAnonymous("System.debug(1);");

  diag Dumper $res;

}


done_testing();
