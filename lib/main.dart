import 'package:flutter/material.dart';

void main() {
  runApp(NestedRouterDemo());
}

class Book {
  final String title;
  final String author;

  Book(this.title, this.author);
}

class NestedRouterDemo extends StatefulWidget {
  @override
  _NestedRouterDemoState createState() => _NestedRouterDemoState();
}

class _NestedRouterDemoState extends State<NestedRouterDemo> {
  RootRouterDelegate _routerDelegate = RootRouterDelegate();
  RootRouteInformationParser _routeInformationParser =
      RootRouteInformationParser();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Books App',
      routerDelegate: _routerDelegate,
      routeInformationParser: _routeInformationParser,
    );
  }
}

class BooksAppState extends ChangeNotifier {
  int _selectedIndex;

  Book _selectedBook;

  final List<Book> books = [
    Book('Stranger in a Strange Land', 'Robert A. Heinlein'),
    Book('Foundation', 'Isaac Asimov'),
    Book('Fahrenheit 451', 'Ray Bradbury'),
  ];

  BooksAppState() : _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  set selectedIndex(int idx) {
    _selectedIndex = idx;
    if (_selectedIndex == 1) {
      // Remove this line if you want to keep the selected book when navigating
      // between "settings" and "home" which book was selected when Settings is
      // tapped.
      selectedBook = null;
    }
    notifyListeners();
  }

  Book get selectedBook => _selectedBook;

  set selectedBook(Book book) {
    _selectedBook = book;
    notifyListeners();
  }

  int getSelectedBookById() {
    if (!books.contains(_selectedBook)) return 0;
    return books.indexOf(_selectedBook);
  }

  void setSelectedBookById(int id) {
    if (id < 0 || id > books.length - 1) {
      return;
    }

    _selectedBook = books[id];
    notifyListeners();
  }
}

class RootRouteInformationParser extends RouteInformationParser<BookRoutePath> {
  @override
  Future<BookRoutePath> parseRouteInformation(
      RouteInformation routeInformation) async {
    final uri = Uri.parse(routeInformation.location);
    print('parseRouteInformation: $uri');

    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'pageB') {
      return PageBPath();
    } else {
      if (uri.pathSegments.length >= 2) {
        return NestedPageAPath(int.tryParse(uri.pathSegments[1]));
      }
      return PageAPath();
    }
  }

  @override
  RouteInformation restoreRouteInformation(BookRoutePath configuration) {
    print('restoreRouteInformation: $configuration');

    if (configuration is PageAPath) {
      return RouteInformation(location: '/pageA');
    }
    if (configuration is PageBPath) {
      return RouteInformation(location: '/pageB');
    }
    if (configuration is NestedPageAPath) {
      return RouteInformation(location: '/pageA/${configuration.id}');
    }
    return null;
  }
}

class RootRouterDelegate extends RouterDelegate<BookRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<BookRoutePath> {
  final GlobalKey<NavigatorState> navigatorKey;

  BooksAppState appState = BooksAppState();

  RootRouterDelegate() : navigatorKey = GlobalKey<NavigatorState>() {
    appState.addListener(notifyListeners);
  }

  BookRoutePath get currentConfiguration {
    print('RootRouterDelegate currentConfiguration getter');

    if (appState.selectedIndex == 1) {
      return PageBPath();
    } else {
      if (appState.selectedBook == null) {
        return PageAPath();
      } else {
        return NestedPageAPath(appState.getSelectedBookById());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('RootRouterDelegate build');

    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage(
          child: AppShell(appState: appState),
        ),
      ],
      onPopPage: (route, result) {
        if (!route.didPop(result)) {
          return false;
        }

        if (appState.selectedBook != null) {
          appState.selectedBook = null;
        }
        notifyListeners();
        return true;
      },
    );
  }

  @override
  Future<void> setNewRoutePath(BookRoutePath path) async {
    if (path is PageAPath) {
      appState.selectedIndex = 0;
      appState.selectedBook = null;
    } else if (path is PageBPath) {
      appState.selectedIndex = 1;
    } else if (path is NestedPageAPath) {
      appState.setSelectedBookById(path.id);
    }
  }
}

// Routes
abstract class BookRoutePath {}

class PageAPath extends BookRoutePath {}

class PageBPath extends BookRoutePath {}

class NestedPageAPath extends BookRoutePath {
  final int id;

  NestedPageAPath(this.id);
}

// Widget that contains the AdaptiveNavigationScaffold
class AppShell extends StatefulWidget {
  final BooksAppState appState;

  AppShell({
    @required this.appState,
  });

  @override
  _AppShellState createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  InnerRouterDelegate _routerDelegate;
  ChildBackButtonDispatcher _backButtonDispatcher;

  void initState() {
    super.initState();
    _routerDelegate = InnerRouterDelegate(widget.appState);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _routerDelegate.appState = widget.appState;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Defer back button dispatching to the child router
    _backButtonDispatcher = Router.of(context)
        .backButtonDispatcher
        .createChildBackButtonDispatcher();
  }

  @override
  Widget build(BuildContext context) {
    var appState = widget.appState;

    // Claim priority, If there are parallel sub router, you will need
    // to pick which one should take priority;
    _backButtonDispatcher.takePriority();

    return Scaffold(
      appBar: AppBar(),
      body: Router(
        routerDelegate: _routerDelegate,
        backButtonDispatcher: _backButtonDispatcher,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'PageA'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'PageB'),
        ],
        currentIndex: appState.selectedIndex,
        onTap: (newIndex) {
          appState.selectedIndex = newIndex;
        },
      ),
    );
  }
}

class InnerRouterDelegate extends RouterDelegate<BookRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<BookRoutePath> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  BooksAppState get appState => _appState;
  BooksAppState _appState;
  set appState(BooksAppState value) {
    if (value == _appState) {
      return;
    }
    _appState = value;
    notifyListeners();
  }

  InnerRouterDelegate(this._appState);

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        if (appState.selectedIndex == 0) ...[
          FadeAnimationPage(
            child: PageAScreen(
              books: appState.books,
              onTapped: _handleBookTapped,
            ),
            key: ValueKey('PageAKey'),
          ),
          if (appState.selectedBook != null)
            MaterialPage(
              key: ValueKey(appState.selectedBook),
              child: NestedPageAScreen(book: appState.selectedBook),
            ),
        ] else
          FadeAnimationPage(
            child: PageBScreen(),
            key: ValueKey('PageBKey'),
          ),
      ],
      onPopPage: (route, result) {
        appState.selectedBook = null;
        notifyListeners();
        return route.didPop(result);
      },
    );
  }

  @override
  Future<void> setNewRoutePath(BookRoutePath path) async {
    // This is not required for inner router delegate because it does not
    // parse route
    assert(false);
  }

  void _handleBookTapped(Book book) {
    appState.selectedBook = book;
    notifyListeners();
  }
}

class FadeAnimationPage extends Page {
  final Widget child;

  FadeAnimationPage({Key key, this.child}) : super(key: key) {
    print('FadeAnimationPage($key) constructor');
  }

  Route createRoute(BuildContext context) {
    print('FadeAnimationPage($key) createRoute');
    return PageRouteBuilder(
      settings: this,
      pageBuilder: (context, animation, animation2) {
        print('FadeAnimationPage($key) pageBuilder');
        var curveTween = CurveTween(curve: Curves.easeIn);
        return FadeTransition(
          opacity: animation.drive(curveTween),
          child: child,
        );
      },
    );
  }
}

// Screens
class PageAScreen extends StatelessWidget {
  final List<Book> books;
  final ValueChanged<Book> onTapped;

  PageAScreen({
    @required this.books,
    @required this.onTapped,
  }) {
    print('PageAScreen constructor');
  }

  @override
  Widget build(BuildContext context) {
    print('PageAScreen build');
    return Scaffold(
      body: ListView(
        children: [
          for (var book in books)
            ListTile(
              title: Text(book.title),
              subtitle: Text(book.author),
              onTap: () => onTapped(book),
            )
        ],
      ),
    );
  }
}

class NestedPageAScreen extends StatelessWidget {
  final Book book;

  NestedPageAScreen({
    @required this.book,
  }) {
    print('NestedPageAScreen constructor');
  }

  @override
  Widget build(BuildContext context) {
    print('NestedPageAScreen build');
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Back'),
            ),
            if (book != null) ...[
              Text(book.title, style: Theme.of(context).textTheme.headline6),
              Text(book.author, style: Theme.of(context).textTheme.subtitle1),
            ],
          ],
        ),
      ),
    );
  }
}

class PageBScreen extends StatelessWidget {
  PageBScreen() {
    print('PageBScreen constructor');
  }
  @override
  Widget build(BuildContext context) {
    print('PageBScreen build');
    return Scaffold(
      body: Center(
        child: Text('Settings screen'),
      ),
    );
  }
}
