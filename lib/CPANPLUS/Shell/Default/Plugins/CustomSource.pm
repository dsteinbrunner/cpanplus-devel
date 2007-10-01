package CPANPLUS::Shell::Default::Plugins::CustomSource;

use strict;
use CPANPLUS::Error                 qw[error msg];
use CPANPLUS::Internals::Constants;

use Data::Dumper;
use Locale::Maketext::Simple        Class => 'CPANPLUS', Style => 'gettext';


sub plugins {
    return ( cs => 'custom_source' )
}

### XXX Refactor
### XXX note saving tree to make changes permanent

my $Cb;
my $Shell;
my @Index   = ();

sub _uri_from_cache {
    my $self    = shift;
    my $input   = shift;

    ### you gave us a search number    
    my $uri = $input =~ /^\d+$/    
                ? $Index[ $input - 1 ] # remember, off by 1!
                : $input;

    my %files = reverse $Cb->list_custom_sources;

    ### it's an URI we know
    if( my $local = $files{ $uri } ) {
        return wantarray 
            ? ($uri, $local)
            : $uri;
    }
    
    ### couldn't resolve the input
    error(loc("Unknown URI/index: '%1'", $input));
    return;
}

sub _list_custom_sources {
    my $class = shift;
    
    my %files = $Cb->list_custom_sources;
    
    $Shell->__print( loc("Your remote sources:"), $/ ) if keys %files;
    
    my $i = 0;
    while(my($local,$remote) = each %files) {
        $Shell->__printf( "   [%2d] %s\n", ++$i, $remote );

        ### remember, off by 1!
        push @Index, $remote;
    }
    
    $Shell->__print( $/ );
}

sub _list_contents {
    my $class = shift;
    my $input = shift;

    my ($uri,$local) = $class->_uri_from_cache( $input );
    unless( $uri ) {
        error(loc("--contents needs URI parameter"));
        return;
    }        

    my $fh = OPEN_FILE->( $local ) or return;

    $Shell->__printf( "   %s", $_ ) for sort <$fh>;
    $Shell->__print( $/ );
}

sub custom_source {
    my $class   = shift;
    my $shell   = shift;    $Shell  = $shell;   # available to all methods now
    my $cb      = shift;    $Cb     = $cb;      # available to all methods now
    my $cmd     = shift;
    my $input   = shift || '';
    my $opts    = shift || {};

    ### show a list
    if( $opts->{'list'} ) {
        $class->_list_custom_sources;

    } elsif ( $opts->{'contents'} ) {
        $class->_list_contents( $input );
    
    } elsif ( $opts->{'add'} ) {        
        unless( $input ) {
            error(loc("--add needs URI parameter"));
            return;
        }        
        
        $cb->add_custom_source( uri => $input ) 
            and $shell->__print(loc("Added remote source '%1'", $input), $/);
        
        $Shell->__print($/, loc("Remote source contains:"), $/, $/);
        $class->_list_contents( $input );
        
    } elsif ( $opts->{'remove'} ) {
        my($uri,$local) = $class->_uri_from_cache( $input );
        unless( $uri ) {
            error(loc("--remove needs URI parameter"));
            return;
        }        
    
        1 while unlink $local;    
    
        $shell->__print( loc("Removed remote source '%1'", $uri), $/ );

    ### XXX support single uri too
    } elsif ( $opts->{'update'} ) {
        $cb->update_custom_source 
            and $shell->__print(loc("Updated remote sources"), $/);      

    } elsif ( $opts->{'write'} ) {
        $cb->write_custom_source_index( path => $input ) and
            $shell->__print(loc("Wrote remote source index for '%1'", $input), $/);              
            
    } else {
        error(loc("Unrecognized command, see '%1' for help", '/? cs'));
    }
    
    return;
}

sub custom_source_help {
    return loc(
                                                                          $/ .
        '    # Plugin to manage custom sources from the default shell'  . $/ .
        "    # See the 'CUSTOM MODULE SOURCES' section in the "         . $/ .
        '    # CPANPLUS::Backend documentation for details.'            . $/ .
        '    /cs --list                     # list available sources'   . $/ .
        '    /cs --add       URI            # add source'               . $/ .
        '    /cs --remove    URI | INDEX    # remove source'            . $/ .
        '    /cs --contents  URI | INDEX    # show packages from source'. $/ .
        '    /cs --update   [URI | INDEX]   # update source index'      . $/ .
        '    /cs --write     PATH           # write source index'       . $/ 
    );        

}

1;
    
