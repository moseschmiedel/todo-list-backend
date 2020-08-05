use Cro::HTTP::Router;
use JSON::Fast;
use JSON::Schema;
use DB::Pg;

my $pg = DB::Pg.new(conninfo => 'host=localhost port=5432 dbname=todo-list user=todo_list');

my $schema = JSON::Schema.new(
    schema => from-json &{ my $json = '';
			   for 'lib/TodoList/schema/todo.json'.IO.lines
			   -> $line {
			       $line.chomp.trim;
			       $json = $json ~ ' ' ~ $line;
			   }
			   $json; }()
);


sub todo-routes() is export {
    route {
	# Read todo
	get -> UInt $id {
	    my $db = $pg.db;
	    $db.begin;

	    my $todo = $pg.query('select * from todos where id = $1', $id);
	    my $tags = $pg.query('select * from todo_tag where todo_id=$1', $id);

	    $db.commit;
	    $db.finish;

	    if ($todo.defined) {
		my %todo = $todo.hash;

		my @tags = [];
		for $tags.hashes -> $tag {
		    @tags.append($tag<tag_id>);
		}

		%todo<tags> = @tags;

		content 'application/json',
		{ 'message' => "Read todo $id",
		  'result' => %todo };
	    } else {
		not-found 'application/json',
		{ 'message' => "Todo with id $id not found",
		  'id' => $id };
	    }
	}

	# Create todo
	post -> {
	    request-body -> %todo {
		if $schema.validate(%todo) {
		    my $db = $pg.db;
		    $db.begin;

		    my $todo_amount =
		      $pg.query('select * from todos').rows;

		    my $id = $todo_amount + 1;

		    $pg.query('insert into todos (id,title,description) values ($1,$2,$3)', $id, %todo<title>, %todo<desc>);

		    if %todo<tags> {
			for %todo<tags> -> $tag_id {
			    $pg.query('insert into todo_tag (todo_id,tag_id)
					      values ($1,$2)', $id, $tag_id);
			}
		    }
		    $db.commit;
		    $db.finish;

		    created "todo/$id", 'application/json',
		    { 'message' => "Created todo $id",
		      'id' => $id,
		      'request' => %todo };
		} else {
		    bad-request 'application/json',
		    { 'message' => 'Invalid JSON',
		      'request' => %todo };
		}
	    }
	}

	# Update todo
	put -> UInt $id {
	    request-body -> %todo {
		if $schema.validate(%todo) {
		    my $db = $pg.db;
		    $db.begin;

		    $pg.query('update todos set title=$2, description=$3 where id=$1', $id, %todo<title>, %todo<desc>);

		    $pg.query('delete from todo_tag where todo_id=$1', $id);

		    if %todo<tags> {
			for %todo<tags> -> $tag_id {
			    $pg.query('insert into todo_tag (todo_id,tag_id)
					      values ($1,$2)', $id, $tag_id);
			}
		    }

		    $db.commit;
		    $db.finish;

		    content 'application/json',
		    { 'message' => "Update todo $id.",
		      'id' => $id,
		      'request' => %todo };
		} else {
		    bad-request 'application/json',
		    { 'message' => 'Invalid JSON',
		      'id' => $id,
		      'request' => %todo };
		}
	    }
	}

	# Delete todo
	delete -> UInt $id {
	    my $db = $pg.db;
	    $db.begin;

	    $pg.query('delete from todos where id=$1', $id);
	    $pg.query('delete from todo_tag where todo_id=$1', $id);

	    $db.commit;
	    $db.finish;

	    content 'application/json',
	    { 'message' => "Delete todo $id.",
	      'id' => $id };
	}

	# Read all todos
	get -> 'all' {
	    my $db = $pg.db;
	    $db.begin;

	    my $todos = $pg.query('select * from todos');

	    $db.commit;
	    $db.finish;

	    my @todos = [];

	    for $todos.hashes -> $todo {
		my $db = $pg.db;
		$db.begin;

		my $tags = $pg.query('select * from todo_tag where todo_id=$1', $todo<id>);

		$db.commit;
		$db.finish;

		my @tags = [];
		for $tags.hashes -> $tag {
		    @tags.append($tag<tag_id>);
		}

		$todo<tags> = @tags;

		@todos.append($todo);
	    }

	    content 'application/json',
	    { 'message' => 'Read all todos',
	      'result' => @todos };
	}
    }
}
