#!perl

use strict;
use warnings;
use utf8;
use 5.32.0;
use version; our $VERSION = version->declare('v1.0.3');

use Encode qw/encode decode/;
use File::Slurp qw/read_file/;
use HTML::TreeBuilder::XPath;
use HTTP::Cookies;
use JSON::XS qw/encode_json decode_json/;
use LWP::UserAgent;
use Text::CSV_XS qw/csv/;

my $conf = -e 'D:/usr/config.json' ? decode_json(read_file('D:/usr/config.json')) : {};
my $ytg = decode_json(read_file('yotogi.json'));

my $cache = {};
$cache = decode_json(read_file($ytg->{cache})) if -e $ytg->{cache};

my $ua = LWP::UserAgent->new(
    agent => $conf->{userAgent} || "Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv:11.0) like Gecko",
    cookie_jar => HTTP::Cookies->new,
);

my $tenc = $ytg->{term_encoding} || (($^O eq 'MSWin32' || $^O eq 'dos') ? 'cp932' : 'utf8');

my $subject = 0;
do {
    say "subject: $subject";
    sleep 3;
    my $res = $ua->get("http://easy2life.sakura.ne.jp/yotogi2/index.php/$subject.csv");
    if ($res->is_success) {
        my $content = $res->content;

        {
            open my $fh, '>', "$ytg->{csvdir}/$subject.csv" or die $!;
            print $fh $res->content;
            close $fh;
        }

        my $csv;
        {
            open my $fh, '<:encoding(cp932)', "$ytg->{csvdir}/$subject.csv" or die $!;
            $csv = csv(in => $fh, headers => 'lc');
            close $fh;
        }

        foreach my $row (@$csv) {
            my $title = $row->{title};
            my $path = "http://easy2life.sakura.ne.jp/yotogi2/index.php/$row->{subject}/$row->{id}";
            my $author = $row->{name};
            my $posting = $row->{datetime};
            my $update = $row->{lastupdate};
            my $comments = "$row->{responsecount}/$row->{commentcount}";
            my $key = $row->{id};

            $subject = $row->{subject};

            if (exists $cache->{$path}) {
                if ($cache->{$path}{title} ne $title or $cache->{$path}{comments} ne $comments or $cache->{$path}{update} ne $update) {
                    say encode($tenc, $title), "[$subject, $key] Update";
                    sleep 5;
                    mkdir $subject unless -d $subject;
                    save($path, "./$subject/$key.html");
                    $cache->{$path}->@{qw/title author posting update comments/} = ($title, $author, $posting, $update, $comments);
                }
            }
            else {
                say encode($tenc, $title), "[$subject, $key] New";
                sleep 5;
                mkdir $subject unless -d $subject;
                save($path, "./$subject/$key.html");
                $cache->{$path}->@{qw/title author posting update comments/} = ($title, $author, $posting, $update, $comments);
            }
        }
    }
} while ($subject-- > 1);

open my $json, '>', $ytg->{cache} or die $!;
print $json JSON::XS->new->pretty(1)->canonical(1)->utf8->encode($cache);
close $json;

open my $idx, '>:utf8', 'index.txt' or die $!;
say $idx "- $_->[1]/$_->[2].html\n  title: $_->[0]{title}\n  author: $_->[0]{author}\n" for
    sort { $a->[1] <=> $b->[1] || $a->[2] <=> $b->[2] }
    map {
        my $v = $cache->{$_};
        my @e = split /\//, $_;
        [$v, $e[-2], $e[-1]];
    } keys %$cache;
close $idx;

exit;

sub save {
    my ($uri, $file) = @_;
    my $res = $ua->get($uri);
    if ($res->is_success) {
        open my $fh, '>', $file or die;
        print $fh $res->content;
        close $fh;
    }
}
