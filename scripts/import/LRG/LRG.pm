use strict;
use warnings;

package LRG;

use XML::Writer;
use IO::File;
use Data::Dumper;

# ROOT OBJECT
#############

package LRG::LRG;

# constructor
sub new {
    my $file = shift;

    my $lrg;
    
    # get an IO object for the file
    my $output = new IO::File(">$file") or die "Could not write to file $file\n";

    # initialise the XML::Writer object
    # the last two parameters ensure pretty formatting when the file is written
    $lrg->{'xml'} = new XML::Writer(OUTPUT => $output, DATA_INDENT => 2, DATA_MODE => 1);
    
    # initialise the nodes array
    $lrg->{'nodes'} = ();

    # give this root node a name for completeness' sake
    $lrg->{'name'} = 'LRG_ROOT_NODE';
    
    # bless and return
    bless $lrg, 'LRG::LRG';
    return $lrg;
}

# constructor reads XML from file
sub newFromFile {
    my $file = shift;

    my $outfile = shift if @_;

    # create a new LRG root - this can be a specific file
    # or just a temporary file if one is not specified
    my $lrg = LRG::LRG::new(defined $outfile ? $outfile : ".$$.temp.xml");

    # set the current node to the root
    my $current = $lrg;
    my $name;

    # open the file
    open IN, $file or die("Could not read from file $file\n");

    # initiate a blank string to hold the XML
    my $xml_string = '';

    # read in the file
    while(<IN>) {
        chomp;

	# lose leading/trailing whitespace
	s/^\s+//g;
	s/\s+$//g;

	# ignore comment lines
	next if /^\<\?/;

	$xml_string .= $_;
    }

    # get rid of newline and carriage return characters
    $xml_string =~ s/\r+//g;
    $xml_string =~ s/\n+//g;

    close IN;

    my $prev_end = 0;

    # loop through XML tags sequentially
    while($xml_string =~ m/<.+?>/g) {

	# get the matched string and details about it
	my $string = $&;
	my $length = length($string);
	my $pos = pos($xml_string);
	my $start = $pos - $length;
	my $end = $pos;

	# this code searches for content between tags
	if($prev_end >= 1 && $start - $prev_end > 1) {

	    # get substring from the XML string
	    my $temp = substr($xml_string, $prev_end, ($start - $prev_end));

	    # check that it contains word characters
	    if($temp =~ /\w+/) {

		# add content to the current node
		$current->content($temp);
	    }
	}

	# reset the prev_end variable
	$prev_end = $end;

	# get rid of tag open/close characters
	$string =~ s/\<|\>//g;

	# if this is a closing tag, point current to this node's parent
	if($string =~ /^\//) {
	    $current = $current->parent;
        }

	# otherwise this is an opening or empty tag
        else {

	    # split by whitespace
	    my @split = split /\s+/, $string;

	    # the name of the tag is the first element
	    $name = shift @split;

	    # if there are more elements, assume these are additional
	    # key/value pairs to be added
	    if(scalar @split) {
		
		# join
		$string = join " ", @split;

		# change " = " to "="
		$string =~ s/\s*\=\s*/\=/;

		# re-split by space or =
		@split = split /\s+|\=/, $string;

		# create a new hash
		my %data = ();

		# iterate through remaining elements
		while(@split) {

		    # get key/value pair
		    my $key = shift @split;
		    my $val = shift @split;

		    # remove "s and 's as these are converted to HTML form
		    # by XML::Writer
		    $val =~ s/\"|\'//g;
		    
		    # remove trailing / if it's an empty tag
		    $val =~ s/\/$//g;
		    # add the data to the hash
		    $data{$key} = $val;
		}

		# if this is an empty tag (ends with a "/")
		if($string =~ /\/$/) {
		   $current = $current->addEmptyNode($name, \%data);
		   
		   # reset current to this node's parents
		   $current = $current->parent;
		}

		# if this is a normal opening tag
		else {
		    $current = $current->addNode($name, \%data);
	        }
	    }

	    # no extra data elements to add
	    else {
		
		# if this is an empty tag (ends with a "/")
		if($string =~ /\/$/) {
		    $current = $current->addEmptyNode($name);
			
		    # reset current node to this node's parents
		    $current = $current->parent;
		}

		# if this is a normal opening tag
		else {
		    $current = $current->addNode($name);
	        }
	    }
        }
    }

    # return
    return $lrg;
}

# add node
sub addNode {
    my $self = shift;

    my $name = shift;
    
    # look for an additional arg containing
    # data to be written in the tag itself
    my $data = shift if @_;
    
    # check that the data sent is a hash
    if(scalar keys %{$data}) {
	push @{$self->{'nodes'}}, LRG::Node::new($name, $self->{'xml'}, $data);
    }

    # otherwise assume no data
    else {
	push @{$self->{'nodes'}}, LRG::Node::new($name, $self->{'xml'});
    }

    (@{$self->{'nodes'}})[-1]->{'parent'} = $self;

    # return the last node added (i.e. this one)
    return (@{$self->{'nodes'}})[-1];
}

sub addEmptyNode {
    my $self = shift;

    my $name = shift;
    
    # look for an additional arg containing
    # data to be written in the tag itself
    my $data = shift if @_;
    
    # check that the data sent is a hash
    if(scalar keys %{$data}) {
	push @{$self->{'nodes'}}, LRG::Node::newEmpty($name, $self->{'xml'}, $data);
    }

    # otherwise assume no data
    else {
	push @{$self->{'nodes'}}, LRG::Node::newEmpty($name, $self->{'xml'});
    }

    (@{$self->{'nodes'}})[-1]->{'parent'} = $self;

    # return the last node added (i.e. this one)
    return (@{$self->{'nodes'}})[-1];
}

# find node
sub findNode {
    my $self = shift;
    my $name = shift;
    my $data = shift if @_;

    # do a multi find if the name is delimited with "/"s
    return $self->findNodeMulti($name, $data) if $name =~ /\//;
    
    my $found;
    my $match;
    
    # look through the nodes
    foreach my $node(@{$self->{'nodes'}}) {

	# if the name matches
	if(defined $node->name && defined $name && $node->name eq $name) {
	
	    $match = 1;

	    # if we are comparing data too
	    if(scalar keys %$data && scalar keys %{$node->data}) {
		$match = 0;

		my $needed = scalar keys %$data;

		foreach my $key(keys %$data) {
		    next unless defined $node->data->{$key};

		    $match++ if $node->data->{$key} eq $data->{$key};
		}

		$match = ($match == $needed ? 1 : 0);
	    }
	    
	    if($match) {
		$found = $node;
		last;
	    }
	}
	
	last if defined $found;

	# look recursively in any sub-nodes if not found
	$found = $node->findNode($name, $data);
    }

    return $found;
}

# find node given multiple levels
sub findNodeMulti {
    my $self = shift;
    my $name = shift;
    my $data = shift if @_;

    my @levels = split /\s*\/\s*/, $name;

    # if only one level given, do a normal findNode
    if(scalar @levels == 1) {
	return $self->findNode($name, $data);
    }

    else {
	my $current = $self;
	
	while(@levels) {
	    my $level = shift @levels;

	    if(scalar @levels >= 1) {
		$current = $current->findNode($level);
	    }

	    else {
		$current = $current->findNode($level, $data);
	    }
	}

	return $current;
    }
}

# print node
sub printNode {
    my $self = shift;
    
    # if this is an empty tag
    # e.g. <mytag data1="value" />
    if($self->empty) {
        if(scalar keys %{$self->data}) {
	    $self->{'xml'}->emptyTag($self->name, %{$self->data});
	}

	else {
	    $self->{'xml'}->emptyTag($self->name);
	}
    }

    # if there is data for this node print like
    # e.g. <mytag data1="value">
    elsif(scalar keys %{$self->data}) {
	$self->{'xml'}->startTag($self->name, %{$self->data});
    }

    # otherwise just open the bare tag
    # e.g. <mytag>
    else {
	$self->{'xml'}->startTag($self->name);
    }

    if(defined $self->{'content'}) {
	#foreach my $item(@{$node->{'content'}}) {
	$self->{'xml'}->characters($self->content);
	#}
    }

    # recursive iteration
    foreach my $node(@{$self->{'nodes'}}) {
	$node->printNode();
    }

    # end the tag
    $self->{'xml'}->endTag() unless $self->{'empty'};
}

# print all
sub printAll {
    my $self = shift;
    
    # required to open the XML doc
    $self->{'xml'}->xmlDecl('UTF-8');

    $self->{'xml'}->pi('xml-stylesheet', 'type="text/xsl href="lrg2html.xsl"');
    
    # iterate through the nodes recursively
    foreach my $node(@{$self->{'nodes'}}) {
        $node->printNode();
    }
    
    # finish and write the file
    $self->{'xml'}->end();
}

# getter/setter for name
sub name {
    my $self = shift;

    $self->{'name'} = shift if @_;

    return $self->{'name'};
}

# get parent node
sub parent {
    my $self = shift;

    return $self->{'parent'} if defined $self->{'parent'};
}

# getter/setter for data
sub data {
    my $self = shift;

    $self->{'data'} = shift if @_;

    return $self->{'data'};
}

# getter/setter for empty status
sub empty {
    my $self = shift;

    $self->{'empty'} = shift if @_;

    return $self->{'empty'};
}

# getter/setter for content
sub content() {
    my $self = shift;
    
    $self->{'content'} = shift if @_;

    return $self->{'content'};
}

# return this node's position in the array order
sub position() {
    my $self = shift;

    my $pos;

    for my $i(0..(scalar @{$self->parent->{'nodes'}} - 1)) {
	if($self eq $self->parent->{'nodes'}->[$i]) {
	    $pos = $i;
	    last;
	}
    }

    return $pos;
}

# get content from STDIN given a list of fields
sub requestContent() {
    my $self = shift;
    my $input;
    
    foreach my $item(@_) {
	print "Input $item \>";
	$input = <STDIN>;
	chomp $input;

	$self->addNode($item)->content($input);
    }
}

# move a node to a specific position in the array
# NB shunts all others down one so any pos need
# to be recalculated
sub moveTo() {
    my $self = shift;
    my $num = (@_ ? shift : 1);
    #$num--;

    my $pos = $self->position();

    my @nodes = @{$self->parent->{'nodes'}};

    my $last_index = $#nodes;

    my @before = ($pos - 1 >= 0 ? @nodes[0..($pos-1)] : ());
    my @after = ($pos + 1 <= $last_index ? @nodes[($pos+1)..$last_index] : ());

    @nodes = (@before, @after);
    $last_index = $#nodes;

    @before = ($num - 1 >= 0 ? @nodes[0..($num-1)] : ());
    @after = ($num <= $last_index ? @nodes[$num..$last_index] : ());

    @nodes = (@before, $self, @after);

    $self->parent->{'nodes'} = \@nodes;
}





# NODE
######

package LRG::Node;

# inherit some functions from root LRG
our @ISA = "LRG::LRG";

sub new {
    my $name = shift;
    my $xml = shift;
    
    # look for an additional arg containing
    # data to be written in the tag itself
    my $data = shift if @_;

    my @nodes = ();

    my %node = ();
    my $node_ref = \%node;

    $node{'name'} = $name;
    $node{'nodes'} = \@nodes;
    $node{'xml'} = $xml;
    $node{'data'} = (scalar keys %{$data} ? $data : {});
    $node{'empty'} = 0;

    bless $node_ref, 'LRG::Node';
    return $node_ref;
}

sub newEmpty {
    my $name = shift;
    my $xml = shift;
    my $data = shift if @_;

    my $node;

    if(scalar keys %{$data}) {
	$node = LRG::Node::new($name, $xml, $data);
    }

    else {
	$node = LRG::Node::new($name, $xml);
    }

    $node->{'empty'} = 1;

    return $node;
}

1;
