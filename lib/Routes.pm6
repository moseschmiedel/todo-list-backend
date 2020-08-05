use Cro::HTTP::Router;

use TodoList::TodoList;

sub routes() is export {
    route {
	get -> {
	    content 'application/json', { 'message' => 'Hello, world!' };
	}

	include <justdoit api v1> => todolist-routes;
    }
}
