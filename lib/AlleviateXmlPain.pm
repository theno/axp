package AlleviateXmlPain;

use strict;
use warnings;

use utf8;

# The gap between declarations, elements and comments
my $GAP = "\n\n";

# Defines the indention of child elements
my $INDENT = "    ";

# Extra indent for the attributes (suggested: No extra indent)
my $ATTRIBUTE_INDENT = "";

# The names of the XML parts in the $regexes map come from the BNF which defines
# the XML syntax.
#
# XML 1.0 
#  * definition: http://www.w3.org/TR/2008/REC-xml-20081126/
#  * BNF extract: http://mailman.ic.ac.uk/pipermail/xml-dev/1997-March/000143.html
our $regexes = {
  'XMLDecl_ending' => qr/\?>/,
  'XMLDecl' => qr/(.*?)(<\?xml\s+version=(?:(?:"1.0")|(?:'1.0'))(?:\s+[^\s]+)*\s*\?>)(.*)/s,

  'doctypedecl_ending' => qr/>/,
  'doctypedecl' => qr/(.*?)(<!DOCTYPE[^>]+>)(.*)/s,

  'Comment' => qr/(.*?)<!--([^-]*(?:-[^-]+)*)-->(.*)/s,

  'Start_or_Empty_Element' => qr{(.*?)<([^/>\s]+)((?:\s+[^\s=]+\s*=\s*((?:"[^"]*")|(?:'[^']*')))*)\s*(/?>)(.*)}s,
  'attributes' => qr{\s+([^\s=]+\s*=\s*(?:(?:\"[^\"]*\")|(?:'[^']*')))},

  'content_and_end_tag' => qr{^([^>]*?)</([^> \n]+)\s*>(.*)},
};

# Used to print the before-part of a regex match if it exists and the newlines
# before the matched items of a xml-entity.
# @params:
#  $before: the before-part of a regex match
#  $is_first_printout: 1 if this program hasn't printed anything, 0 else
sub print_with_context {
  my ($ref, $before, $gap) = @_;

  $before =~ s/\s*$//; # remove trailing spaces

  if ($ref->{"last_start_tag_unfinished"} == 1) {
    print ">";
    $ref->{"last_start_tag_unfinished"} = 0;
  }

  if ( $before !~ /^$/ ) {
    print "${before}${gap}"; # before is not empty
  }
  elsif ( ! $ref->{"is_first_printout"} ) {
    print "$gap";
  }
}

sub print_indented {
  my ($str_before, $indent_level, $str_after) = @_;

  print "$str_before";
  foreach (1 .. $indent_level) { print "$INDENT"; }
  print "$str_after";
}

sub xml_declaration {
  my ($ref) = @_;
  return prolog_part($ref, $regexes->{"XMLDecl"}, $regexes->{"XMLDecl_ending"});
}
sub doctype_declaration {
  my ($ref) = @_;
  return prolog_part($ref, $regexes->{"doctypedecl"}, $regexes->{"doctypedecl_ending"});
}
sub prolog_part {
  my ($ref, $re_match, $re_del) = @_;

  if ( $ref->{"in"} =~ $re_match ) {

    my ($before, $prolog_part, $after) = ($1, $2, $3);

    print_with_context($ref, $before, $GAP);

    $prolog_part =~ s/\s+/ /g;
    $prolog_part =~ s/\s?($re_del)$/$1/;
    print $prolog_part;

    $ref->{"in"} = $after;
    $ref->{"indent_level"} = 0;
    $ref->{"is_first_printout"} = 0;

    return 1;
  }
  return 0;
}

sub comment {
  my ($ref) = @_;

  if ( $ref->{"in"} =~ $regexes->{"Comment"} ) {

    my ($before, $comment, $after) = ($1, $2, $3);

    print_with_context($ref, $before, $GAP);

    $comment =~ s/^\s*$//m;

    if ($comment !~ /^$/) {
      my $indent_level = $ref->{"indent_level"};
      print_indented("", $indent_level, "<!--\n");
      for my $nonempty_line ($comment =~ /^(?:\s*)(.*)(?:\s*)$/mg) {
        print_indented("", $indent_level, "$nonempty_line\n");
      }
      print_indented("", $indent_level, "-->");
    }

    $ref->{"in"} = $after;
    $ref->{"is_first_printout"} = 0;

    return 1;
  }
  return 0;
}

# element einleitung finden
# zeilen einlesen bis tag komplett (abbruch, wenn start neuer start-tag)
#  attribute extrahieren
#  attribute umbrechen
# wenn start tag, dann
#  content end-tag
sub start_or_empty_element {
  my ($ref) = @_;

  if ( $ref->{"in"} =~ $regexes->{"Start_or_Empty_Element"} ) {

    my $before = $1;
    my $after = $6;

    my $elem_name = $2;
    my $ending = $5;
    my @attributes = $3 =~ /$regexes->{"attributes"}/g;

    print_with_context($ref, $before, $GAP);

    print_indented("", $ref->{"indent_level"}, "<$elem_name");

    my $attr_exist = 0;
    for my $attribute (@attributes) {
      $attribute =~ s/(?<=[^\s=])(\s*=\s*)/=/; # remove optional space before and after '='
      print_indented("\n", $ref->{"indent_level"} + 1, "${ATTRIBUTE_INDENT}${attribute}");
      $attr_exist = 1;
    }

    # attributes and/or empty element
    if ($attr_exist or $ending =~ "^/") {
      print_indented("\n", $ref->{"indent_level"} + 1, "");
    }

    if ($ending =~ "^/>") {
      # empty element
      print "/>";
    }
    else {
      # start tag
      push @{$ref->{"open_tags"}}, $elem_name;
      $ref->{"indent_level"} += 1;
      $ref->{"last_start_tag_unfinished"} = 1;
      if ($attr_exist) {
        $ref->{"last_start_tag_has_attribute"} = 1;
      }
      else {
        $ref->{"last_start_tag_has_attribute"} = 0;
      }
    }

    $ref->{"in"} = $after;
    $ref->{"is_first_printout"} = 0;

    return 1;
  }
  return 0;
}

sub content_and_end_tag {
  my ($ref) = @_;

  if ( $ref->{"in"} =~ $regexes->{"content_and_end_tag"} ) {

    my ($content, $name, $after) = ($1, $2, $3);

    $content =~ s/\s+$//; #TODO add multiline emptyness-support

    #fallback to $name if open_tags-stack is empty (possible on non-xml)
    my $elem_name = pop @{$ref->{"open_tags"}} || "$name";

    close_element($elem_name, $content, $ref);

    $ref->{"in"} = $after;
    $ref->{"is_first_printout"} = 0;

    return 1;
  }
  return 0;
}

sub close_element {
  my ($elem_name, $content, $ref) = @_;

  if ($content =~ /^$/ and $ref->{"last_start_tag_unfinished"}) {
    if ($ref->{"last_start_tag_has_attribute"}) {
      $ref->{"last_start_tag_has_attribute"} = 0;
    }
    else {
      print_indented("\n", $ref->{"indent_level"}, "");
    }
    print "/>";
    $ref->{"last_start_tag_unfinished"} = 0;
  }
  else {
    print_with_context($ref, $content, "");

    $content =~ s/\s+$//;
    if ($content =~ /^$/ ) {
      print_indented($GAP, $ref->{"indent_level"} - 1, "");
    }
    print "</$elem_name>";
  }

  $ref->{"indent_level"} -= 1;
}

sub xml_2_pretty_xml {

  my $states_ref = {
    "in" => "",
    "is_first_printout" => 1,
    "indent_level" => 0,
    "last_start_tag_unfinished" => 0,
    "last_start_tag_has_attribute" => 0,
    "open_tags" => []
  };

  while (my $line = <STDIN>) {

    $states_ref->{"in"} .= $line;

    while (
      xml_declaration($states_ref)
      || doctype_declaration($states_ref)
      || comment($states_ref)
      || content_and_end_tag($states_ref)
      || start_or_empty_element($states_ref) # 'start_or_empty_element' must be after 'content_and_end_tag'
    ) {}
  }

  while (my $elem_name = pop @{$states_ref->{'open_tags'}}) {
    close_element($elem_name, "", $states_ref);
  }

  # delete space-prefixes and -postfixes
  $states_ref->{"in"} =~ s/(?:^\s+|\s+$)//g;
  # trim inline-spaces
  $states_ref->{"in"} =~ s/(?:^[ \t]+|[ \t]+$)//mg;
  if ($states_ref->{'in'} !~ /^\s*$/) {
    print "${GAP}$states_ref->{'in'}";
  }
}

1;
