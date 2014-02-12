#!/usr/bin/perl

BEGIN { push @INC, "../lib/"; }

use strict;
use warnings;

use Data::Dumper; # DEBUG
#use Test::More tests => 2;
use Test::More 'no_plan';
use YAML::Tiny;

use AlleviateXmlPain;

my @OUTPUT_FUNCTIONS = qw/comment content_and_end_tag doctype_declaration xml_declaration start_or_empty_element/;


# Tests of the regexes

# TODO: describe params
sub test_regex_match {
  my ($re, $data_ref) = @_;

  my $s = $data_ref->{'string'};
  my @res = $s =~ $re;

  # test if match success
  if( ok(@res, "match: $data_ref->{'comment'}") ) {
  
    # test if captures are correct

    my $captures_ref = $data_ref->{'captures'};
    my $captures_size = $#$captures_ref + 1;
    
    for (my $i = 0; $i < $captures_size; $i++) {
      # note: {{{ $res[$i] || "" }}} changes undef to "", so you can define empty captures via yaml
      is_deeply($res[$i] || "", @$captures_ref[$i]->{'val'}, "$data_ref->{'comment'} - @$captures_ref[$i]->{'comment'}");
    }
  }
  else {
    print "#   * regex: $re\n#   * string: \'$s\'\n";
  }
}

#print "\nregexes:\n\n";

my $yaml = YAML::Tiny->read("testdata/regex.yaml") or die "Could not open or load yaml-file: $!";
#print Dumper($yaml->[0]);

for my $ref (@{$yaml->[0]}) {
  my $key = $ref->{'regex_name'};
  test_regex_match($AlleviateXmlPain::regexes->{$key}, $ref);
};

my $re = $AlleviateXmlPain::regexes->{"XMLDecl"};
my $s = "";
#print "\nregex xml declaration: $re\n\n";
$s = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
ok($s =~ /$re/, "=~ $s");
$s = '<?xmlversion="1.0" encoding="UTF-8" standalone="yes"?>';
ok($s !~ /$re/, "!~ $s");

$re = $AlleviateXmlPain::regexes->{'doctypedecl'};
$s = "";
#print "\nregex doctype declaration: $re\n\n";

$s = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">';
ok($s =~ /$re/, "=~ $s");

$s = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"';
ok($s !~ /$re/, "!~ $s");

$re = $AlleviateXmlPain::regexes->{'Start_or_Empty_Element'};
$s = "";
#print "\nregex start tag or empty element: $re\n\n";


$s = '<start_tag>';
ok($s =~ /$re/, "=~ $s");

$s = "<empty_element/>";
ok($s =~ /$re/, "=~ $s");

$s = '<start_tag hihi= "hoho">';
ok($s =~ /$re/, "=~ $s -> <start_tag hihi=\"hoho\">");

$s = '<empty_element hihi ="hoho"/>';
ok($s =~ /$re/, "=~ $s");

$s = '<empty_element hihi = "hoho"/>';
ok($s =~ /$re/, "=~ $s");

$s = '</end_tag>';
ok($s !~ /$re/, "!~ $s");

$re = $AlleviateXmlPain::regexes->{'attributes'};
$s = "";

#print "\nregex attributes: $re\n\n";


# tests of functions producing the output

#print "\nfunctions producing the output\n\n";

# TODO: Describe input params
sub test_output_function {
  my ($func_name, $states_ref, $must_after, $comment) = @_;

  my $func_ref = \&{$func_name};
  my $output = "";

  open(TOOUTPUT, '>', \$output) or die "Can't open TOOUTPUT: $!";
  select TOOUTPUT;

  $func_ref->(($states_ref));

  select STDOUT;
  close(TOOUTPUT);

  my $is = { 'output' => $output, 'states_ref' => $states_ref };

  is_deeply($is, $must_after, "$func_name(): $comment");
}

for my $func_name (@OUTPUT_FUNCTIONS) {
  my $yaml_filename = "testdata/output_functions/$func_name.yaml";
  my $yaml = YAML::Tiny->read($yaml_filename) or die "Could not open or load yaml-file '${yaml_filename}': $!";
  for my $ref (@{$yaml->[0]}) {
#    print Dumper($ref->{'before'}->{'states_ref'}); #TODO DEBUG
    test_output_function($ref->{'function'}, $ref->{'before'}->{'states_ref'}, $ref->{'must_after'}, $ref->{'comment'});
  };
}

sub test_xml_2_pretty_xml {
  my ($xml_before, $xml_must) = @_;

  my $output = "";

  open(XML_MUST, '<', "$xml_must") or die "Cant't open $xml_must: $!";
  my $must = "";
  while (<XML_MUST>) { $must .= $_; }
  close(XML_MUST);

  close(STDIN);
  open(STDIN, '<', "$xml_before") or die "Can't open $xml_before: $!";

  open(TOOUTPUT, '>', \$output) or die "Can't open TOOUTPUT: $!";
  select(TOOUTPUT);

  AlleviateXmlPain::xml_2_pretty_xml();
  
  select(STDOUT);
  close(TOOUTPUT);
  $output .= "\n";

  is_deeply($output, $must, $xml_before);
}

sub run_tests_xml_2_pretty_xml {

  my $dir_name = "testdata/xml_2_pretty_xml/";

  opendir(DIR, $dir_name) or die "Can't open $dir_name: $!";
  my @must_files = grep{ /^must-\d+\.xml$/ } readdir(DIR);
  close(DIR);

  my @numbers = @must_files;
  s/\D*(\d+).*/$1/ for @numbers;
  @numbers = reverse @numbers;
  @must_files = reverse @must_files;
 
  my %h;
  for (my $j = 0; $j < $#must_files + 1; $j++) {
    $h{$must_files[$j]} = $numbers[$j];
  }

  for my $key (keys %h) {
    my $i = $h{$key};

    opendir(DIR, $dir_name) or die "Can't open $dir_name: $!";
    my @data_files = grep{ /^data-$i/ } readdir(DIR);
    close(DIR);

    @data_files = reverse @data_files;

    my $sum = @data_files;
    if ( $sum == 0) { die "no testdata for test no $i"; }

    for my $d (@data_files) {
      test_xml_2_pretty_xml("testdata/xml_2_pretty_xml/$d", "testdata/xml_2_pretty_xml/$key");
    }
  }
}

run_tests_xml_2_pretty_xml();
