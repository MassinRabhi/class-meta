package Class::Meta::Method;

# $Id: Method.pm,v 1.20 2004/01/09 03:35:53 david Exp $

=head1 NAME

Class::Meta::Method - Class::Meta class method introspection

=head1 SYNOPSIS

  # Assuming MyApp::Thingy was generated by Class::Meta.
  my $class = MyApp::Thingy->class;
  my $thingy = MyApp::Thingy->new;

  print "\nMethods:\n";
  for my $meth ($class->methods) {
      print "  o ", $meth->name, $/;
      $meth->call($thingy);
  }

=head1 DESCRIPTION

This class provides an interface to the C<Class::Meta> objects that describe
methods. It supports a simple description of the method, a label, and its
visibility (private, protected, or public).

Class::Meta::Method objects are created by Class::Meta; they are never
instantiated directly in client code. To access the method objects for a
Class::Meta-generated class, simply call its C<class> method to retrieve its
Class::Meta::Class object, and then call the C<methods()> method on the
Class::Meta::Class object.

=cut

##############################################################################
# Dependencies                                                               #
##############################################################################
use strict;

##############################################################################
# Package Globals                                                            #
##############################################################################
our $VERSION = "0.01";

##############################################################################
# Private Package Globals
##############################################################################
my $croak = sub {
    require Carp;
    our @CARP_NOT = qw(Class::Meta);
    Carp::croak(@_);
};

##############################################################################
# Constructors                                                               #
##############################################################################
# We don't document new(), since it's a protected method, really. Its
# parameters are documented in Class::Meta.

sub new {
    my $pkg = shift;
    my $spec = shift;

    # Check to make sure that only Class::Meta or a subclass is constructing a
    # Class::Meta::Method object.
    my $caller = caller;
    $croak->("Package '$caller' cannot create " . __PACKAGE__ . " objects")
        unless UNIVERSAL::isa($caller, 'Class::Meta');

    # Make sure we can get all the arguments.
    $croak->("Odd number of parameters in call to new() when named "
             . "parameters were expected" ) if @_ % 2;
    my %p = @_;

    # Validate the name.
    $croak->("Parameter 'name' is required in call to new()")
      unless $p{name};
    $croak->("Method '$p{name}' is not a valid method name "
             . "-- only alphanumeric and '_' characters allowed")
      if $p{name} =~ /\W/;

    # Make sure the name hasn't already been used for another method
    # or constructor.
    $croak->("Method '$p{name}' already exists in class "
             . "'$spec->{package}'")
      if exists $spec->{meths}{$p{name}}
      || exists $spec->{ctors}{$p{name}};

    # Check the visibility.
    if (exists $p{view}) {
        $croak->("Not a valid view parameter: '$p{view}'")
          unless $p{view} == Class::Meta::PUBLIC
          ||     $p{view} == Class::Meta::PROTECTED
          ||     $p{view} == Class::Meta::PRIVATE;
    } else {
        # Make it public by default.
        $p{view} = Class::Meta::PUBLIC;
    }

    # Check the context.
    if (exists $p{context}) {
        $croak->("Not a valid context parameter: '$p{context}'")
          unless $p{context} == Class::Meta::OBJECT
          ||     $p{context} == Class::Meta::CLASS;
    } else {
        # Make it public by default.
        $p{context} = Class::Meta::OBJECT;
    }

    # Validate or create the method caller if necessary.
    if ($p{caller}) {
        my $ref = ref $p{caller};
        $croak->("Parameter caller must be a code reference")
          unless $ref && $ref eq 'CODE'
      } else {
          $p{caller} = eval "sub { shift->$p{name}(\@_) }"
            if $p{view} > Class::Meta::PRIVATE;
      }

    # Create and cache the method object.
    $p{package} = $spec->{package};
    $spec->{meths}{$p{name}} = bless \%p, ref $pkg || $pkg;

    # Index its view.
    if ($p{view} > Class::Meta::PRIVATE) {
        push @{$spec->{prot_meth_ord}}, $p{name};
        push @{$spec->{meth_ord}}, $p{name}
          if $p{view} == Class::Meta::PUBLIC;
    }

    # Let 'em have it.
    return $spec->{meths}{$p{name}};
}

##############################################################################
# Instance Methods                                                           #
##############################################################################

=head1 INTERFACE

=head2 Instance Methods

=head3 name

  my $name = $meth->name;

Returns the method name.

=head3 package

  my $package = $meth->package;

Returns the method package.

=head3 desc

  my $desc = $meth->desc;

Returns the description of the method.

=head3 label

  my $desc = $meth->label;

Returns label for the method.

=head3 view

  my $view = $meth->view;

Returns the view of the method, reflecting its visibility. The possible
values are defined by the following constants:

=over 4

=item Class::Meta::PUBLIC

=item Class::Meta::PRIVATE

=item Class::Meta::PROTECTED

=back

=head3 context

  my $context = $meth->context;

Returns the context of the method, essentially whether it is a class or
object method. The possible values are defined by the following constants:

=over 4

=item Class::Meta::CLASS

=item Class::Meta::OBJECT

=back

=cut

sub name    { $_[0]->{name}    }
sub package { $_[0]->{package} }
sub desc    { $_[0]->{desc}    }
sub label   { $_[0]->{label}   }
sub view    { $_[0]->{view}    }
sub context { $_[0]->{context} }

=head3 call

  my $ret = $meth->call($obj, @args);

Calls the method on the C<$obj> object, passing in any arguments.

=cut

sub call {
    my $self = shift;
    my $code = $self->{caller}
      or $croak->("Cannot call method '", $self->name, "'");
    $code->(@_);
}

1;
__END__

=head1 AUTHOR

David Wheeler <david@kineticode.com>

=head1 SEE ALSO

Other classes of interest within the Class::Meta distribution include:

=over 4

=item L<Class::Meta|Class::Meta>

=item L<Class::Meta::Class|Class::Meta::Class>

=item L<Class::Meta::Constructor|Class::Meta::Constructor>

=item L<Class::Meta::Attribute|Class::Meta::Attribute>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002-2004, David Wheeler. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
