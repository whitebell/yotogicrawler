#!perl

use strict;
use warnings;
use utf8;
use 5.32.0;
use version; our $VERSION = version->declare('v1.0.8');

use Encode qw/encode decode/;
use File::Slurp qw/read_file/;
use HTML::TreeBuilder::XPath;
use HTTP::Cookies;
use HTTP::Status qw/:constants/;
use JSON::XS qw/decode_json/;
use LWP::UserAgent;

my $conf = decode_json(read_file('config.json'));
my $comp = decode_json(read_file('comp.json'));

my $ua = LWP::UserAgent->new(
    agent => $conf->{userAgent} || "Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv:11.0) like Gecko",
    cookie_jar => HTTP::Cookies->new,
);

my $tenc = $conf->{term_encoding} || (($^O eq 'MSWin32' || $^O eq 'dos') ? 'cp932' : 'utf8');

foreach my $c (keys %$comp) {
    say $c;
    my $cache = {};
    $cache = decode_json(read_file($comp->{$c}{cache})) if -e $comp->{$c}{cache};

    mkdir $comp->{$c}{dir} unless -d $comp->{$c}{dir};

    my $uri = URI->new($comp->{$c}{uri});

    sleep 3;
    my $t = 0;
    my $res;
    do {
        say "  Retry $t" if $t;
        sleep $t++ * 3;
        $res = $ua->get($uri);
    } until ($res->is_success || $res->code != HTTP_SERVICE_UNAVAILABLE || $t == 11);
    if ($res->is_success) {
        open my $fh, '>', "./$comp->{$c}{dir}/index.html" or die $!; ###
        print $fh $res->content;
        close $fh;

        my $tree = HTML::TreeBuilder::XPath->new;
        $tree->parse_file("./$comp->{$c}{dir}/index.html"); ###
        my $results = $tree->findnodes($comp->{$c}{xpath}{nodeset});

        die if !$results->isa('XML::XPathEngine::NodeSet');

        foreach my $n ($results->get_nodelist) {
            my $title    = $n->findvalue($comp->{$c}{xpath}{title});
            my $path     = $n->findvalue($comp->{$c}{xpath}{path});
            my $author   = $n->findvalue($comp->{$c}{xpath}{author});
            my $posting  = $n->findvalue($comp->{$c}{xpath}{posting});
            my $comments = $n->findvalue($comp->{$c}{xpath}{comments});
            my $update   = exists $comp->{$c}{xpath}{update} ? $n->findvalue($comp->{$c}{xpath}{update}) : undef;

            foreach ($title, $author, $posting, $update, $comments) {
                next unless $_;
                $_ = decode('cp932', $_);
                $_ = trim($_);
            }

            $path = URI->new($path)->abs($uri);
            die unless $path =~ m/key=(\d+)/;
            my $key = $1;
            if (exists $cache->{$path}) {
                if ($cache->{$path}{title} ne $title || $cache->{$path}{comments} ne $comments || ($update and $cache->{$path}{update} ne $update)) {
                    say encode($tenc, $title);
                    sleep 5;
                    save($path, "./$comp->{$c}{dir}/$key.html"); ###
                    $cache->{$path}->@{qw/title author posting comments/} = ($title, $author, $posting, $comments);
                    $cache->{$path}{update} = $update if $update;
                }
            }
            else {
                say encode($tenc, $title);
                sleep 5;
                save($path, "./$comp->{$c}{dir}/$key.html"); ###
                $cache->{$path}->@{qw/title author posting comments/} = ($title, $author, $posting, $comments);
                $cache->{$path}{update} = $update if $update;
            }
        }
    }
    else {
        warn $res->status_line;
    }

    open my $json, '>', $comp->{$c}{cache} or die $!;
    print $json JSON::XS->new->pretty(1)->canonical(1)->utf8->encode($cache);
    close $json;
}
exit;

sub trim {
    (my $s = shift) =~ s/^ *(.*?) *$/$1/;
    return $s;
}

sub save {
    my ($uri, $file) = @_;
    my $t = 0;
    my $res; # HTTP::Response
    do {
        say "  Retry $t" if $t;
        sleep $t++ * 3;
        $res = $ua->get($uri);
    } until ($res->is_success || $res->code != HTTP_SERVICE_UNAVAILABLE || $t == 11);
    if ($res->is_success) {
        open my $fh, '>', $file or die;
        print $fh $res->content;
        close $fh;
    }
    else {
        warn $res->status_line;
    }
}
