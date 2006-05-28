package Class::Meta::Method;

# $Id$

=head1 NAME

Class::Meta::Method - Class::Meta class method introspection

=head1 SYNOPSIS

  # Assuming MyApp::Thingy was generated by Class::Meta.
  my $class = MyApp::Thingy->my_class;
  my $thingy = MyApp::Thingy->new;

  print "\nMethods:\n";
  for my $meth ($class->methods) {
      print "  o ", $meth->name, $/;
      $meth->call($thingy);
  }

=head1 DESCRIPTION

This class provides an interface to the C<Class::Meta> objects that describe
methods. It supports a simple description of the method, a label, and its
visibility (private, protected, trusted, or public).

Class::Meta::Method objects are created by Class::Meta; they are never
instantiated directly in client code. To access the method objects for a
Class::Meta-generated class, simply call its C<my_class()> method to retrieve
its Class::Meta::Class object, and then call the C<methods()> method on the
Class::Meta::Class object.

=cut

##############################################################################
# Dependencies                                                               #
##############################################################################
use strict;

##############################################################################
# Package Globals                                                            #
##############################################################################
our $VERSION = "0.53";

=head1 INTERFACE

=head2 Constructors

=head3 new

A protected method for constructing a Class::Meta::Method object. Do not call
this method directly; Call the L<C<add_method()>|Class::Meta/"add_method">
method on a Class::Meta object, instead.

=cut

sub new {
    my $pkg = shift;
    my $class = shift;

    # Check to make sure that only Class::Meta or a subclass is constructing a
    # Class::Meta::Method object.
    my $caller = caller;
    Class::Meta->handle_error("Package '$caller' cannot create $pkg "
                              . "objects")
      unless UNIVERSAL::isa($caller, 'Class::Meta')
        || UNIVERSAL::isa($caller, __PACKAGE__);

    # Make sure we can get all the arguments.
    $class->handle_error("Odd number of parameters in call to new() "
                                 . "when named parameters were expected")
      if @_ % 2;

    my %p = @_;

    # Validate the name.
    $class->handle_error("Parameter 'name' is required in call to "
                                 . "new()") unless $p{name};
    $class->handle_error("Method '$p{name}' is not a valid method "
             . "name -- only alphanumeric and '_' characters allowed")
      if $p{name} =~ /\W/;

    # Make sure the name hasn't already been used for another method
    # or constructor.
    $class->handle_error("Method '$p{name}' already exists in class "
             . "'$class->{package}'")
      if exists $class->{meths}{$p{name}}
      || exists $class->{ctors}{$p{name}};

    # Check the visibility.
    if (exists $p{view}) {
        $class->handle_error("Not a valid view parameter: '$p{view}'")
          unless $p{view} == Class::Meta::PUBLIC
          ||     $p{view} == Class::Meta::PROTECTED
          ||     $p{view} == Class::Meta::TRUSTED
          ||     $p{view} == Class::Meta::PRIVATE;
    } else {
        # Make it public by default.
        $p{view} = Class::Meta::PUBLIC;
    }

    # Check the context.
    if (exists $p{context}) {
        $class->handle_error("Not a valid context parameter: "
                                     . "'$p{context}'")
          unless $p{context} == Class::Meta::OBJECT
          ||     $p{context} == Class::Meta::CLASS;
    } else {
        # Make it public by default.
        $p{context} = Class::Meta::OBJECT;
    }

    # Validate or create the method caller if necessary.
    if ($p{caller}) {
        my $ref = ref $p{caller};
        $class->handle_error(
            'Parameter caller must be a code reference'
        ) unless $ref && $ref eq 'CODE'
    } else {
        $p{caller} = eval "sub { shift->$p{name}(\@_) }"
            if $p{view} > Class::Meta::PRIVATE;
    }

    if ($p{code}) {
        my $ref = ref $p{code};
        $class->handle_error(
            'Parameter code must be a code reference'
        ) unless $ref && $ref eq 'CODE';
    }

    # Create and cache the method object.
    $p{package} = $class->{package};
    $class->{meths}{$p{name}} = bless \%p, ref $pkg || $pkg;

    # Index its view.
    push @{ $class->{all_meth_ord} }, $p{name};
    if ($p{view} > Class::Meta::PRIVATE) {
        push @{$class->{prot_meth_ord}}, $p{name}
          unless $p{view} == Class::Meta::TRUSTED;
        if ($p{view} > Class::Meta::PROTECTED) {
            push @{$class->{trst_meth_ord}}, $p{name};
            push @{$class->{meth_ord}}, $p{name}
              if $p{view} == Class::Meta::PUBLIC;
        }
    }

    # Store a reference to the class object.
    $p{class} = $class;

    # Let 'em have it.
    return $class->{meths}{$p{name}};
}

##############################################################################
# Instance Methods                                                           #
##############################################################################

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

=item Class::Meta::TRUSTED

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

=head3 args

A description of the arguments to the method. This can be anything you like,
but I recommend something like a string for a single argument, an array
reference for a list of arguments, or a hash reference for parameter
arguments.

=head3 returns

A description of the return value or values of the method.

=head3 class

  my $class = $meth->class;

Returns the Class::Meta::Class object that this method is associated
with. Note that this object will always represent the class in which the
method is defined, and I<not> any of its subclasses.

=cut

sub name    { $_[0]->{name}    }
sub package { $_[0]->{package} }
sub desc    { $_[0]->{desc}    }
sub label   { $_[0]->{label}   }
sub view    { $_[0]->{view}    }
sub context { $_[0]->{context} }
sub args    { $_[0]->{args}    }
sub returns { $_[0]->{returns} }
sub class   { $_[0]->{class}   }

=head3 call

  my $ret = $meth->call($obj, @args);

Calls the method on the C<$obj> object, passing in any arguments. Note that it
uses a C<goto> to execute the method, so the call to C<call()> itself will not
appear in a call stack trace.

=cut

sub call {
    my $self = shift;
    my $code = $self->{caller}
      or $self->class->handle_error("Cannot call method '", $self->name, "'");
    goto &$code;
}

##############################################################################

=head3 build

  $meth->build($class);

This is a protected method, designed to be called only by the Class::Meta
class or a subclass of Class::Meta. It takes a single argument, the
Class::Meta::Class object for the class in which the method was defined. Once
it checks to make sure that it is only called by Class::Meta or a subclass of
Class::Meta or of Class::Meta::Method, C<build()> installs the method if it
was specified via the C<code> parameter to C<new()>.

Although you should never call this method directly, subclasses of
Class::Meta::Method may need to override it in order to add behavior.

=cut

sub build {
    my ($self, $class) = @_;

    # Check to make sure that only Class::Meta or a subclass is building
    # methods.
    my $caller = caller;
    $self->class->handle_error(
        "Package '$caller' cannot call " . ref($self) . "->build"
    ) unless UNIVERSAL::isa($caller, 'Class::Meta')
        || UNIVERSAL::isa($caller, __PACKAGE__);

    # Install the method if we've got it.
    if (my $code = delete $self->{code}) {
        my $pack = $self->package;
        my $name = $self->{name};
        no strict 'refs';
        *{"$pack\::$name"} = $code;
    }

    return $self;
}

1;
__END__

=head1 BUGS

Please send bug reports to <bug-class-meta@rt.cpan.org> or report them via the
CPAN Request Tracker at L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Meta>.

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

Copyright (c) 2002-2005, David Wheeler. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
