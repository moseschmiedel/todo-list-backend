use Cro::HTTP::Router;
use JSON::Fast;
use JSON::Schema;

my $schema = JSON::Schema.new(
    schema => from-json &{ my $json = '';
			   for 'lib/TodoList/schema/tag.json'.IO.lines
			   -> $line {
			       $line.chomp.trim;
			       $json = $json ~ ' ' ~ $line;
			   }
			   $json; }()
);


sub tag-routes() is export {
    route {
	# Read tag
	get -> UInt $id {
	    content 'application/json',
	    { 'message' => "Read tag $id" };
	}

	# Create tag
	post -> {
	    request-body -> %tag {
		if $schema.validate(%tag) {
		    my $id = 1;
		    created "tag/$id", 'application/json',
		    { 'message' => "Created tag $id",
		      'id' => $id,
		      'request' => %tag }
		} else {
		    bad-request 'application/json',
		    { 'message' => 'Invalid JSON',
		      'request' => %tag };
		}
	    }
	}

	# Update tag
	put -> UInt $id {
	    request-body -> %tag {
		if $schema.validate(%tag) {
		    content 'application/json',
		    { 'message' => "Updated tag $id",
		      'id' => $id,
		      'request' => %tag };
		} else {
		    bad-request 'application/json',
		    { 'message' => 'Invalid JSON',
		      'request' => %tag };
		}
	    }
	}

	# Delete tag
	delete -> UInt $id {
	    content 'application/json',
	    { 'message' => "Delete tag $id" };
	}

	# Read all tags
	get -> 'all' {
	    content 'application/json',
	    { 'message' => 'Read all tags' };
	}
    }
}
