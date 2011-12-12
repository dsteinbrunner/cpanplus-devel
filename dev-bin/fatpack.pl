use strict;
use warnings;
use Cwd qw[cwd];
use File::Find qw[find];
use File::Spec::Functions qw[
  catdir splitpath splitdir catpath rel2abs abs2rel
];
use B qw[perlstring];

$|=1;

open my $fat, '>', 'cpanp-fat' or die "$!\n";
my $fatpacked = '#!/usr/bin/env perl' . "\n" . fatpack_files() . open_cpanp();
print {$fat} $fatpacked;
close $fat;
exit 0;

sub open_cpanp {
  my $cpanp = do {
    open my $CPANP, '<', 'bin/cpanp' or die "Doh $!\n";
    local $/;
    <$CPANP>
  };
  $cpanp =~ s|#!/usr/bin/perl||;
  return $cpanp;
}

sub stripspace {
  my ($text) = @_;
  $text =~ /^(\s+)/ && $text =~ s/^$1//mg;
  $text;
}

sub fatpack_files {
  my $cwd = cwd;
  my @dirs = map rel2abs($_, $cwd), ('lib','inc/bundle');
  my %files;
  foreach my $dir (@dirs) {
    find(sub {
      return unless -f $_;
      !/\.pm$/ and warn "File ${File::Find::name} isn't a .pm file - can't pack this and if you hoped we were going to things may not be what you expected later\n" and return;
      $files{abs2rel($File::Find::name,$dir)} = do {
        local (@ARGV, $/) = ($File::Find::name); <>
      };
    }, $dir);
  }
  my $start = stripspace <<'  END_START';
    # This chunk of stuff was generated by App::FatPacker. To find the original
    # file's code, look for the end of this BEGIN block or the string 'FATPACK'
    BEGIN {
    my %fatpacked;
  END_START
  my $end = stripspace <<'  END_END';
    s/^  //mg for values %fatpacked;

    my $i = 0;
    unshift @INC, sub {
      if (my $fat = $fatpacked{$_[1]}) {
        my $fatfile = "/tmp/fat_pack_" . $i;
        $i++;
        open my $wfh, '>', $fatfile or die "Error opening file";
        print { $wfh } $fat;
        close $wfh;
        open my $fh, '<', $fatfile;
        unlink $fatfile;
        return $fh;
      }
      return
    };

    } # END OF FATPACK CODE
  END_END
  my @segments = map {
    (my $stub = $_) =~ s/\.pm$//;
    my $name = uc join '_', split '/', $stub;
    my $data = $files{$_}; $data =~ s/^/  /mg; $data =~ s/(?<!\n)\z/\n/;
    '$fatpacked{'.perlstring($_).qq!} = <<'${name}';\n!
    .qq!${data}${name}\n!;
  } sort keys %files;
  return join "\n", $start, @segments, $end;
}
