use Cro::HTTP::Router;

use TodoList::Todo;
use TodoList::Tag;


sub todolist-routes() is export {
    route {
	include todo     => todo-routes,
		tag      => tag-routes;
    }
}
