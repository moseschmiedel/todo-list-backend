use Cro::HTTP::Router;
use JSON::Fast;
use JSON::Schema;
use DB::Pg;

my $pg = DB::Pg.new(conninfo => 'host=localhost port=5432 dbname=todo-list user=todo_list');

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
	    my $db = $pg.db;
	    $db.begin;

	    my $tag = $pg.query('select * from tags where id = $1', $id);
	    my $todos = $pg.query('select * from todo_tag where tag_id=$1', $id);

	    $db.commit;
	    $db.finish;

	    if ($tag.defined) {
		my %tag = $tag.hash;

		my @todos = [];
		for $todos.hashes -> $todo {
		    @todos.append($todo<todo_id>);
		}

		%tag<todos> = @todos;

		content 'application/json',
		{ 'message' => "Read tag $id",
		  'result' => %tag };
	    } else {
		not-found 'application/json',
		{ 'message' => "Tag with id $id not found",
		  'id' => $id };
	    }
	}

	# Create tag
	post -> {
	    request-body -> %tag {
		if $schema.validate(%tag) {
		    my $db = $pg.db;
		    $db.begin;

		    my $tag_amount =
		      $pg.query('select * from tags').rows;

		    my $id = $tag_amount + 1;

		    $pg.query('insert into tags (id,title,description,color) values ($1,$2,$3,$4)', $id, %tag<title>, %tag<desc>, %tag<color>);

		    if %tag<todos> {
			for %tag<todos> -> $todo_id {
			    $pg.query('insert into todo_tag (todo_id,tag_id)
					      values ($1,$2)', $todo_id, $id);
			}
		    }
		    $db.commit;
		    $db.finish;

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
		    my $db = $pg.db;
		    $db.begin;

		    $pg.query('update tags set title=$2, description=$3, color=$4 where id=$1', $id, %tag<title>, %tag<desc>, %tag<color>);

		    $pg.query('delete from todo_tag where tag_id=$1', $id);

		    if %tag<todos> {
			for %tag<todos> -> $todo_id {
			    $pg.query('insert into todo_tag (todo_id,tag_id)
					      values ($1,$2)', $todo_id, $id);
			}
		    }

		    $db.commit;
		    $db.finish;

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
	    my $db = $pg.db;
	    $db.begin;

	    $pg.query('delete from tags where id=$1', $id);
	    $pg.query('delete from todo_tag where tag_id=$1', $id);

	    $db.commit;
	    $db.finish;

	    content 'application/json',
	    { 'message' => "Delete tag $id",
	      'id' => $id };
	}

	# Read all tags
	get -> 'all' {
	    my $db = $pg.db;
	    $db.begin;

	    my $tags = $pg.query('select * from tags');

	    $db.commit;
	    $db.finish;

	    my @tags = [];

	    for $tags.hashes -> $tag {
		my $db = $pg.db;
		$db.begin;

		my $todos = $pg.query('select * from todo_tag where tag_id=$1', $tag<id>);

		$db.commit;
		$db.finish;

		my @todos = [];
		for $todos.hashes -> $todo {
		    @todos.append($todo<todo_id>);
		}

		$tag<todos> = @todos;

		@tags.append($tag);
	    }

	    content 'application/json',
	    { 'message' => 'Read all tags',
	      'result' => @tags };
	}
    }
}
