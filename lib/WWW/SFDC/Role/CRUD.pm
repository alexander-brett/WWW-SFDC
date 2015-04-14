package WWW::SFDC::Role::CRUD;

use 5.12.0;
use strict;
use warnings;

use Moo::Role;

requires qw'';

# BASICALLY SHARED METHODS BETWEEN PARTNER AND TOOLING APIs

=head2 query

    say $_->{Id} for WWW::SFDC::Partner->instance()->query($queryString);

=cut

sub query {
  my ($self, $query) = @_;
  INFO "Executing SOQL query: ".$query;

  my $result = $self->_call(
    'query',
    SOAP::Data->name(queryString => $query),
);

  return ref $result->{records} eq 'ARRAY'
    ? map {$self->_cleanUpSObject($_)} @{$result->{records}}
    : ( $self->_cleanUpSObject($result->{records}) );
}

sub _cleanUpSObject {
  my ($self, $obj) = @_;
  return () unless $obj;
  my %copy = %$obj; # strip the class from $obj
  $copy{Id} = $copy{Id}->[0] if ref $copy{Id} eq "ARRAY";
  return \%copy;
}

=head2 create

    say "$$_{id}:\t$$_{success}" for WWW::SFDC::Partner->instance()->update(
      {type => 'thing', Id => 'foo', Field__c => 'bar', Name => 'baz'}
      {type => 'otherthing', Id => 'bam', Field__c => 'bas', Name => 'bat'}
    );

=cut

sub create {
  my $self = shift;

  return $self->_call(
    'create',
    $self->_prepareSObjects(@_)
   );
}

=head2 update

    say "$$_{id}:\t$$_{success}" for WWW::SFDC::Partner->instance()->update(
      {type => 'thing', Id => 'foo', Field__c => 'bar', Name => 'baz'}
      {type => 'otherthing', Id => 'bam', Field__c => 'bas', Name => 'bat'}
    );

Returns an array that looks like [{success => 1, id => 'id'}, {}...] with LOWERCASE keys.

=cut

sub update {
  my $self = shift;

  DEBUG "Objects for update" => @_;
  INFO "Updating objects";

  return $self->_call(
    'update',
    $self->_prepareSObjects(@_)
   );
}

1;
