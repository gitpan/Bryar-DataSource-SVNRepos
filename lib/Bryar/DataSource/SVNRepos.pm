package Bryar::DataSource::SVNRepos;
use 5.006;
use strict;
use warnings;

use SVN::Core;
use SVN::Repos;
use SVN::Fs;

use Bryar::Document;

use Time::Piece;

our $VERSION=0.01;

=head1 NAME

Bryar::DataSource::SVNRepos - Blog entries from a subversion repository

=head1 SYNOPSIS

	$self->all_documents(...);
	$self->search(...);

=head1 DESCRIPTION

This data source gets its blog entries from a local subversion repository.
It expects that all the files in the repository are blog entries; you can't
use only a subdirectory.

=cut

my ($repo, $fs, $root);

sub id_to_path {
	return $_[0];
}

sub path_to_id {
	$_[0] =~ s|^/||;
	return $_[0];
}

sub get_dir_entries {
	my ($root, $path) = @_;

	my @documents;

		if ($path !~ m|/$|) {
		  $path .= "/";
	        }
	foreach my $entry (values %{$root->dir_entries ($path)}) {
		my $entry_path = $path . $entry->name;
		if ($entry->kind == $SVN::Node::file) {
			push (@documents, document_from_entry ($path, $entry_path));
		} elsif ($entry->kind == $SVN::Node::dir) {
			push (@documents, get_dir_entries ($root, $entry_path . '/'));
		} else {
			# ??
		}
	}
	return sort {$b->{epoch} <=> $a->{epoch}} @documents;
}

sub document_from_entry {
	my ($path, $entry) = @_;

	my $category = $path;
	$category =~ s|^/||;
	my $content_handle = $root->file_contents ("$entry");
	my ($title, $content);
	{	$title = <$content_handle>;
		chomp $title;
		local $/;
		$content = <$content_handle>;
	}
	my $logdata = get_log_info ($entry);
	my $epoch = Time::Piece->strptime (substr ($logdata->[$#$logdata]->{date}, 0, 19), "%Y-%m-%dT%T")->epoch;
	my $updated = Time::Piece->strptime (substr ($logdata->[0]->{date}, 0, 19), "%Y-%m-%dT%T")->epoch;

	my $author = $logdata->[0]->{'author'};

	my $doc = Bryar::Document->new (
		epoch => $epoch,
		updated => $updated,
		content => $content,
		author => $author,
		category =>  $category,
		title => $title,
		id => path_to_id ($entry),
	);
	return $doc;
}

sub get_log_info {
	my ($path) = @_;

	my @data;
	$repo->get_logs ([$path], $fs->youngest_rev, 0, 0, 0, 
		sub {
			my ($paths, $rev, $author, $date, $msg, $pool) = @_;
			push @data, {rev => $rev, author => $author, date => $date };
		});
	return \@data;
}

=head1 METHODS

=head2 all_documents

Returns all documents in the repository.

=cut

sub all_documents {
   my ($self, $bryar) = @_;

   my $datadir = $bryar->{config}->{repos};
   $repo = SVN::Repos::open ($datadir) || die $!;
   $fs = $repo->fs;
   $root = $fs->revision_root ($fs->youngest_rev);
   my $path = "/";
   get_dir_entries ($root, $path);
}

=head2 search

Lets you select specific entries. See Bryar::DataSource::Base for more
information.

=cut

sub search {
   my ($self, $bryar, %params) = @_;

   use Data::Dumper;
   my $datadir = $bryar->{config}->{repos};
   $repo = SVN::Repos::open ($datadir) || die $!;
   $fs = $repo->fs;
   $root = $fs->revision_root ($fs->youngest_rev);
   my $path = "/";

   my @docs;
   if (defined $params{'id'}) {
      my $entrypath = id_to_path ($params{'id'});
      my $entry;
      if ($entrypath =~ m|/|) {
	 ($entrypath, $entry) = ($entrypath =~ m|(.*)/([^/]*)|g);
	 $path .= $entrypath;
      } else {
	 my $subpath = ($params{'subblog'} || '');
	 $entry = "$subpath/$entrypath";
	 $path .= "$subpath/";
      }
      push (@docs, document_from_entry ($path, $entry));
      return @docs;
   }
   if (defined $params{'subblog'}) {
      $path .= $params{'subblog'};
   }

   foreach my $doc (get_dir_entries ($root, $path)) {
      next if (defined $params{'since'} and $doc->epoch > $params{'since'});
      next if (defined $params{'before'} and $doc->epoch < $params{'before'});
      next if (defined $params{'contains'}
	       and $doc->content =~ /\Q$params{'contains'}\E/);
      push (@docs, $doc);
      last if (defined $params{'limit'} and @docs >= $params{'limit'});
   }

   return @docs;
}

# we don't do comments.
sub add_comment {}

=head1 BUGS

This data source doesn't handle comments.
It fetches the version of each document that is in the youngest revision.
Only tested with Bryar::Frontend::Static and my post-commit script.

=head1 AUTHOR

Copyright (C) 2004, Martijn van Beers C<martijn@cpan.org>

=cut

1;

