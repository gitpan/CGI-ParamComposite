=head1 NAME

CGI::ParamComposite - Convert .-delimited CGI parameters to Perl classes/objects

=head1 SYNOPSIS

  use CGI;
  use CGI::ParamComposite;
  my $q = CGI->new();
  my $c = CGI::ParamComposite->new( populate => 0 , cgi => $q );

  #Dumper([$composite->roots()]) returns (minor formatting):
  $VAR1 = [
     bless( {}, 'CGI::ParamComposite' )
  ];


  my $c = CGI::ParamComposite->new( populate => 1 , cgi => $q , package => 'market');

  #Dumper([$composite->roots()]) returns (minor formatting):
  $VAR1 = [
    bless( {
      'food' => bless( {
        'market::food::meat' => [
          'pork',
          'beef',
          'fish'
        ],
        'market::food::vegetable' => [
          'tomato',
          'spinach'
        ]
      }, 'market::food' )
    }, 'market' )
  ];

  #either way, these calls now work:
  my($market) = $composite->roots();
  ref($market);                                       #returns "market"
  ref($market->food);                                 #returns "market::food"
  join(', ', map {ref($_)} $market->food->children(); #returns "market::food::meat, market::food::vegetable"

=head1 DESCRIPTION

I needed this for a fairly large single-CGI script application that I was working on.
It was a script that had been actively, organically growing for 4+ years, and was
getting very difficult to track the undocumented 50+ CGI parameters that were being
passed, some of them dynamically generated, and almost all with very short names.

I wanted a way to organize the parameters, to make it easier to set up some simple
guidelines for how to maintain parameters, and how to make sure they were accessable
in a consistent manner.  I decided to use a hierarchical, dot-delimited convention
similar to what you seen in some programming languages.  Now if I see a parameter
like:

/my.cgi?gbrowse.param.navigation.instructions=1

I can pretty quickly guess, after not looking at the code for days/weeks/months, that
this value is somehow affecting the instructions on the Gbrowse navigation page.  In
my opinion, this is superior to:

/my.cgi?ins=0

which had the same effect in an earlier version of the code (negated logic :o).

=head1 SEE ALSO

L<CGI>, L<Symbol>

=head1 AUTHOR

Allen Day, E<lt>allenday@ucla.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Allen Day

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.

=HEAD1 METHODS

=cut

package CGI::ParamComposite;

use strict;
use CGI;
use Symbol;
use constant DEBUG => 0;
our $VERSION = '0.01';

my $self = undef;

=head2 new()

 Usage   : my $c = CGI::ParamComposite->new( populate => 1 , package => 'My::Param' );
           my @roots = $c->roots(); #these are what you're after
 Function: builds and returns a new CGI::ParamComposite object.  calls L</init()>,
           which is where all the action happens.
 Returns : a CGI::ParamComposite instance
 Args    : all optional:
             cgi         - a CGI object from which params() are retrieved.
             populate    - should the objects returned by L</roots()> be fleshed out?
                           defaults to false, this is fastest.
             package     - prefix to attach to new symbols.  see L</package()> for
                           details.

=cut

sub new {
  my ($self,@args) = @_;


}


sub new {
  my($class,%arg) = @_;
  return $self if defined($self);

  $self = bless {}, $class;
  $self->init(%arg);
  return $self;
}

=head2 init()

 Usage   : $obj->init(%arg);
 Function: initializes a CGI::ParamComposite object.  this includes
           registration of new packages, package constructors, and
           package accessors into the Perl symbol table.
 Returns : true on success.
 Args    : none.  this is an internal method called by L</new()>.


=cut

sub init {
  my ($self,@args) = @_;


}
sub init {
  my($self,%arg) = @_;

  $self->package($arg{package} || __PACKAGE__);
  $self->populate($arg{populate});
  $self->cgi($arg{cgi} || new CGI);

  return unless $self->cgi->param();

  my %baby = ();
  my %slot = ();
  my %mama = ();

  foreach my $p (sort {depth($b) <=> depth($a)} $self->cgi->param()){
    my @baby = split '\.', $p;
    unshift @baby, $self->package() if defined($self->package());
    my $slit  = pop @baby;

    my @mama = @baby;

    my $baby = join('::',@baby);
    my $slot = join('::',(@baby,$slit));
    my $mama = join('::',@mama);

    while(@mama){
      my $daughter = pop @mama;

      if(@mama && !$baby{ join('::',(@mama,$daughter)) }++){
        #print "*baby ".join('::',(@mama,$daughter))."\n";
        $self->packit( join('::',(@mama,$daughter)) );
      }

      my $mama = join('::',@mama);
      if(@mama && !$mama{$mama}){
        #print "$mama\n" if $mama;
        $self->packit($mama);
        #print "  ".join('::',(@mama,$daughter))."\n";
      }

      push @{ $mama{$mama} }, [join('::',(@mama,$daughter)),$daughter];
    }

    if(!$mama{$slot} && !$slot{$slot}){
      $self->slotit($slot,$p);
      $slot{$slot} = $baby;
    }
  }

  my @eves = ();
  foreach my $mama (keys %mama){
    no strict 'refs';
    #print "$mama\n";
    push @eves, $mama unless $baby{$mama};
    #print "  is root\n" unless $baby{$mama};

    my @babies = ();
    foreach my $baby (@{ $mama{$mama} }){
      my($pack,$slot) = @$baby;
      push @babies, $slot;

      my $slotsymbol = qualify(join('::',($mama,$slot))) or die "couldn't qualify symbol for $mama::$slot: $!";
      *$slotsymbol = sub {
        my($self) = @_;
        $self->{$slot} ||= bless {}, $pack;
        return $self->{$slot};
      };
    }

    #print $mama."\n";
    #print "  ".join(' ',@babies)."\n";

    my $slotsymbol = qualify(join('::',($mama,'children'))) or die "couldn't qualify symbol for $mama::children: $!";
    *$slotsymbol = sub {
      my($self) = @_;
      my @tots = ();
      foreach my $baby (@babies){
        push @tots, $self->$baby();
      }
      return @tots;
    };
  }

  my @roots = ();
  foreach my $eve (@eves){
    next unless $eve;
    my $root =  bless {}, $eve;
    push @roots, $root;
  }
  $self->{'roots'} = \@roots;
  treeit(\%slot,@roots) if $self->populate();

  1;
}

=head1 ACCESSORS

=head2 cgi()

 Usage   : $obj->cgi($newval)
 Function: holds a CGI instance.  this is instantiated by L</init()>,
           if you don't provide a value.
 Returns : value of cgi (a CGI object)
 Args    : on set, new value (a scalar or undef, optional)


=cut

sub cgi {
  my($self,$val) = @_;
  $self->{'cgi'} = $val if defined($val);
  return $self->{'cgi'};
}

=head2 package()

 Usage   : $obj->package($newval)
 Function: base package to use for composite's subclasses,
           for instance if package was 'Foo::Bar', and
           CGI::ParamComposite received the CGI parameter
           string:

             "baz.boo=1;bad.boo=2"

           packages "Foo::Bar::baz" and "Foo::Bar::boo" would
           be created (each with a boo() method).

           the value defaults to "CGI::ParamComposite" for
           safety reasons.
 Returns : value of package (a scalar)
 Args    : on set, new value (a scalar or undef, optional)


=cut

sub package {
  my($self,$val) = @_;
  $self->{'package'} = $val if defined($val);
  return $self->{'package'};
}

=head2 populate()

 Usage   : $obj->populate($boolean)
 Function: determines whether or not daughters of the root-level
           nodes are populated when a new object is built.  defaults
           to false.  objects/values are still accessible, but not
           pre-created for you (so a Data::Dumper::Dumper() on 
           CGI::ParamComposite->roots() won't tell you much, for
           instance.
 Returns : value of populate (a boolean)
 Args    : on set, new value (a boolean or undef, optional)


=cut

sub populate {
  my($self,$val) = @_;
  $self->{'populate'} = $val if defined($val);
  return $self->{'populate'};
}


=head2 roots()

 Usage   : $obj->roots()
 Function: call this to get the top-level composite objects.  call children()
           on each of these (recursively) to get the child objects.
 Returns : value of roots (a list of objects)
 Args    : none


=cut

sub roots {
  my($self) = @_;
  return $self->{'roots'} ? @{ $self->{'roots'} } : ();
}

=head1 INTERNAL METHODS

You donn't need to touch these.

=head2 packit()

 Usage   : internal method, creates a package new() constructor

=cut

sub packit {
  my ($self,$pack) = @_;

  my $packsymbol = qualify($pack) or die "couldn't qualify symbol for $pack: $!";
  my $newsymbol = qualify("$pack::new") or die "couldn't qualify symbol for $pack::new: $!";
  no strict 'refs';
  *$newsymbol = sub {
    return bless {}, $packsymbol;
  };
}

=head2 slotit()

 Usage   : internal method, creates a package get/set accessor

=cut

sub slotit {
  my ($self,$slot,$p) = @_;

  my $slotsymbol = qualify($slot) or die "couldn't qualify symbol for $slot: $!";
  my @vals = $self->cgi->param($p);
  no strict 'refs';
  *$slotsymbol = sub {
    my($self,@new) = @_;
    if(!$self->{$slot} && !@new){
      @{ $self->{$slot} } = @vals;
    } elsif(@new){
      @{ $self->{$slot} } = @new;
    }

    #@vals = @new if @new;
    #return @vals;
    return @{ $self->{$slot} };
  }
}

=head2 depth()

 Usage   : internal method, used for sorting CGI params based
           on the depth of their namespace.  this makes sure
           the created symbols return the right thing (child
           objects or simple scalars)

=cut

sub depth {
  my $string = shift;
  my @parts = split '\.', $string;
  return scalar(@parts);
}

=head2 treeit()

 Usage   : internal method, used to recursively fill slots
           when L</populate()> returns a true value.

=cut

sub treeit {
  my ($slot,@nodes) = @_;
  foreach my $node (@nodes){
    foreach my $s (keys %$slot){
      if(ref($node) eq $slot->{$s}){
        $node->$s(); #initialize
        delete($slot->{$s});
      }
    }
    next unless $node->can('children');
    treeit($slot,$node->children);
  }
}

1;
__END__
