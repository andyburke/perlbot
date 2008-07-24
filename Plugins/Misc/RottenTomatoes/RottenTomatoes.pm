# Rotten Tomatoes - v1.0
# 
# author: Paul Sharpe <downer@nimh.net>
#
# Will get the freshness rating of a movie from rottentomatoes.com

package Perlbot::Plugin::RottenTomatoes;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);

use LWP::UserAgent;

our $VERSION = '1.0.0';

sub init
{
    my $self = shift;

    $self->hook('rt', \&rt);
}

sub rt
{
    my $self = shift;
    my $user = shift;
    my $text = shift;

    if(!$text)
    {
        $self->reply("Please enter a movie title.");

        return;
    }

    # replace all spaces w/ +'s for the search url
    
    $text =~ s/ /+/g;

    # Hash to store review results

    my %results = ();

    # We're using the movie.php search script which will either return the
    # review page itself if there's only one match, or it'll return a list
    # of matches that we'll then take the top match and go on to the review
    # page for that match.  Not perfect, but the best that can be done with
    # the way rt handles searches.

    my $searchURL = "http://www.rottentomatoes.com/search/movie.php?search=$text";

    my $ua = new LWP::UserAgent;
    my $request = new HTTP::Request('GET', $searchURL);

    my $response = $ua->request($request);

    unless($response->is_success)
    {
        $self->reply_error('Could not connect/timed out to Rotten Tomatoes.');

        return;
    }

    my $content = $response->content();


    # If the title still has ROTTEN in it, it's a search result page

    if($content =~ /<title>ROTTEN/)
    {
        %results = parse_results_page($content);
    }
    else
    {
        %results = parse_review_page($content);
    }

    if($results{error})
    {
        $self->reply_error($results{error});

        return;
    }

    my $title = "Movie Title: " . substr($results{title}, 0, 60);
    if(length($results{title}) > 60) { $title .= "..."; }

    $self->reply($title);
    $self->reply("[ $results{rating} $results{reading} ] Cream: $results{cream} Reviews: $results{counted} (Fresh: $results{fresh} Rotten: $results{rotten})");

}

sub parse_review_page
{
    my $content = shift;

    my %results = ();

    my @lines = split(/\n/, $content);

    for(my $i = 0; $i < @lines; $i++)
    {
        my $line = $lines[$i];
        
        if($line =~ /<title>(.*?)</)
        {
            $results{title} = $1;
        }

        if($line =~ /RATING:<\/a>&nbsp;<a class="movie-body-text-bold">(.*?)<\/a>&nbsp;&nbsp;<a class="movie-info-text3">READING:<\/a>&nbsp;<a class="movie-body-text-bold">(.*?)</)
        {
            $results{rating} = $1;
            $results{reading} = $2;
        }
        
        if($line =~ /Reviews counted:&nbsp;<\/a><a class="movie-body-text">(.*?)<\/a>&nbsp;&nbsp;<br><a class="movie-body-text-bold">Fresh:&nbsp; <\/a><a class="movie-body-text">(.*?)<\/a>&nbsp;&nbsp;<a class="movie-body-text-bold">Rotten:&nbsp;<\/a><a class="movie-body-text">(.*?)</)
        {
            $results{counted} = $1;
            $results{fresh} = $2;
            $results{rotten} = $3;
        }
        
        if($line =~ />Cream of the Crop</)
        {
            $line = $lines[$i + 3];
            
            $line =~ /align=center><b>(.*?)</;
            
            $results{cream} = $1;
            
            last;
        }
    }

    return %results;
}


sub parse_results_page
{
    my $content = shift;

    my %results = ();

    my $reviewURL = "http://www.rottentomatoes.com";

    my @lines = split(/\n/, $content);

    for(my $i = 0; $i < @lines; $i++)
    {
        my $line = $lines[$i];

        if($line =~ /CARD TOP CAP/)
        {
            $line = $lines[$i + 3];
            
            $line =~ /<a class=table-hl-header-link href=(.*?)>/;
            
            $reviewURL .= $1;

            last;
        }
        
        if($line =~ /<a class=movie-link href=(.*?)>/)
        {
            $reviewURL .= $1;
            
            last;
        }
        
        if($line =~ /Page 1 of 0/)
        {
            $results{error} = "No results found.";

            return %results;
        }
    }

    my $ua = new LWP::UserAgent;
    my $request = new HTTP::Request('GET', $reviewURL);

    my $response = $ua->request($request);

    unless($response->is_success)
    {
        $results{error} = "Could not connect/timed out to Rotten Tomatoes.";

        return %results;
    }

    $content = $response->content();

    %results = parse_review_page($content);

    return %results;
}

1;
