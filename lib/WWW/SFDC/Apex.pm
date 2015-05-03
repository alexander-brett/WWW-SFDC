#!/usr/bin/env perl

package WWW::SFDC::Apex;

use 5.12.0;
use strict;
use warnings;

use Log::Log4perl ':easy';
use WWW::SFDC::SessionManager;

use Moo;
with "MooX::Singleton", "WWW::SFDC::Role::Session";

use SOAP::Lite;

our $VERSION = '0.1';

has 'uri',
    is => 'ro',
    default=> "http://soap.sforce.com/2006/08/apex";

sub _extractURL {
    return $_[1]->{serverUrl} =~ s{/u/}{/s/}r;
}

sub compileAndTest {
  my ($self, @names) = @_;

  return $self->_call(
    'compileAndTest',
    map {\SOAP::Data->name(classes => $_)} @names
    );
}

sub compileClasses {
  my ($self, @names) = @_;

  return $self->_call(
    'compileClasses',
    SOAP::Data->value(map {SOAP::Data->name(scripts => $_)} @names)
    );
}

sub compileTriggers {
  my ($self, @names) = @_;

  return $self->_call(
    'compileTriggers',
    map {\SOAP::Data->name(classes => $_)} @names
    );
}

sub executeAnonymous {
  my ($self, $code, %options) = @_;
  my ($result, $headers) = $self->_call(
    'executeAnonymous',
    SOAP::Data->name(string => $code),
    $options{debug} ? SOAP::Header->name('DebuggingHeader' => \SOAP::Data->name(
        debugLevel => 'DEBUGONLY'
      ))->uri($self->uri) : (),
   );

  
  LOGDIE "ExecuteAnonymous failed to compile: " . $result->{compileProblem}
    if $result->{compiled} eq "false";

  LOGDIE "ExecuteAnonymous failed to complete: " . $result->{exceptionMessage}
    if ($result->{success} eq "false");

  return $result, (defined $headers ? $headers->{debugLog} : ());
}

sub runTests {
  my ($self, @names) = @_;

  return $self->_call(
    'runTests',
    map {\SOAP::Data->name(classes => $_)} @names
    );
}

sub wsdlToApex {
    ...
}

1;
