package Koha::Plugin::No::Libriotech::Jatakk;

use Modern::Perl;
use LWP::Simple;
use JSON;
use Data::Dumper;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Auth;
use C4::Context;
use Koha::Plugins::Tab; # To make intranet_catalog_biblio_tab work

use Data::Dumper;

## Here we set our plugin version
our $VERSION = "0.1";
our $MINIMUM_VERSION = "21.11";
our $api_base_url = 'https://depotbiblioteket.no/r/jatakk/1.0/data/mode=check?';

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Jatakk',
    author          => 'Magnus Enger',
    date_authored   => '2023-02-24',
    date_updated    => "2023-02-24",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     => 'Support for the Jatakk REST API from the Norwegian depot library.',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    $self->{cgi} = CGI->new();

    return $self;
}

## The existance of a 'tool' subroutine means the plugin is capable
## of running a tool. The difference between a tool and a report is
## primarily semantic, but in general any plugin that modifies the
## Koha database should be considered a tool
sub tool {
    
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'main.tt' });

    $self->output_html( $template->output() );

}

sub data {
    
    my ( $self, $args ) = @_;

    my $template = $self->get_template({
        file => 'data.tt'
    });

    my $biblionumber = scalar $self->{cgi}->param('biblionumber');

    # Find the biblio
    my $biblio = Koha::Biblios->find( $biblionumber );

    # Find the ISBNs
    my $isbn_string = $biblio->biblioitem->isbn;
    my @isbns = split / \| /, $isbn_string;

    # Fetch the data
    my @datas;
    foreach my $isbn ( @isbns ) {
        my $url = $api_base_url . "isbn=$isbn"   ;
        my $data_raw = get( $url );
        my $data;
        if ( $data_raw ) {
            $data = decode_json( $data_raw );
            $data->{ 'x_data_raw' } = $data_raw;
        } else {
            $data->{ 'x_error' } = "Could not fetch the data!";
        }
        $data->{ 'x_isbn' } = $isbn;
        $data->{ 'x_url' } = $url;
        push @datas, $data;
    }

    $template->param(
        biblionumber => $biblionumber,
        biblio       => $biblio,
        datas        => \@datas,
    );
    $self->output_html( $template->output() );

}

## This method allows you to add new html elements to the catalogue toolbar.
## You'll want to return a string of raw html here, most likely a button or other
## toolbar element of some form. See bug 20968 for more details.
sub intranet_catalog_biblio_enhancements_toolbar_button {
    my ( $self ) = @_;

    my $template = $self->get_template({
        file => 'biblio_toolbar_button.tt'
    });
    $template->param(
        biblionumber => scalar $self->{cgi}->param('biblionumber'),
    );
    return $template->output;

}

1;
