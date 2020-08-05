use Cro::HTTP::Log::File;
use Cro::HTTP::Server;
use Routes;

my Cro::Service $http = Cro::HTTP::Server.new(
    http => <1.1>,
    host => %*ENV<TODO_LIST_HOST> ||
        die("Missing TODO_LIST_HOST in environment"),
    port => %*ENV<TODO_LIST_PORT> ||
        die("Missing TODO_LIST_PORT in environment"),
    application => routes(),
    after => [
        Cro::HTTP::Log::File.new(logs => $*OUT, errors => $*ERR)
    ]
);
$http.start;
say "Listening at http://%*ENV<TODO_LIST_HOST>:%*ENV<TODO_LIST_PORT>";
react {
    whenever signal(SIGINT) {
        say "Shutting down...";
        $http.stop;
        done;
    }
}
