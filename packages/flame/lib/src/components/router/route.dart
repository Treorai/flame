import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/src/components/router/router_component.dart';
import 'package:flame/src/effects/effect.dart';
import 'package:flame/src/rendering/decorator.dart';
import 'package:meta/meta.dart';

/// [Route] is a light-weight component that builds and manages a page.
///
/// The "page" is a generic concept here: it is any component that comprises a
/// distinct UI arrangement. Pages are usually full-screen, for example: a
/// splash-screen page, a loading page, a game menu page, a level selection
/// page, a character creation page, and so on. Pages may also occupy less than
/// the full screen. These can be: a confirmation popup, an "enter name" dialog
/// box, a character inventory panel, a UI for dialogue with an NPC, etc.
///
/// Most routes are created when the game is initialized, and thus they should
/// try to be as lightweight as possible. In particular, a [Route] should avoid
/// any potentially costly initialization operations.
///
/// Routes are managed by the [RouterComponent] component.
class Route extends PositionComponent
    with ParentIsA<RouterComponent>, HasTimeScale {
  Route(
    Component Function()? builder, {
    Component Function()? loadingBuilder,
    this.transparent = false,
    this.maintainState = true,
  })  : _builder = builder,
        _loadingBuilder = loadingBuilder,
        _renderEffect = Decorator();

  /// If true, then the route below this one will continue to be rendered when
  /// this route becomes active. If false, then this route is assumed to
  /// completely obscure any route that would be underneath, and therefore the
  /// route underneath doesn't need to be rendered.
  final bool transparent;

  /// If false, the route will not maintain the state of this route's page
  /// component.  By default, once a route becomes active, the component
  /// built by the build routine is maintained by the route after the route
  /// is popped off the stack. Setting [maintainState] to false will drop the
  /// page component when the route is popped off the stack.
  final bool maintainState;

  /// The name of the route (set by the [RouterComponent]).
  String? get name => _name;
  String? _name;
  @internal
  set name(String? value) => _name = value;

  /// The function that will be invoked in order to build the page component
  /// when this route first becomes active. This function may also be `null`,
  /// in which case the user must override the [build] method.
  final Component Function()? _builder;

  /// The function that will build the loading page component, which is shown
  /// when this route first becomes active, but hasn't fully loaded yet.
  final Component Function()? _loadingBuilder;

  /// This method is invoked when the route is pushed on top of the
  /// [RouterComponent]'s stack.
  ///
  /// The argument for this method is the route that was on top of the stack
  /// before the push. It can be null if the current route becomes the first
  /// element of the navigation stack.
  void onPush(Route? previousRoute) {}

  /// This method is called when the route is popped off the top of the
  /// [RouterComponent]'s stack.
  ///
  /// The argument for this method is the route that will become the next
  /// top-most route on the stack. Thus, the argument in [onPop] will always be
  /// the same as was given previously in [onPush].
  void onPop(Route nextRoute) {}

  /// Creates the page component managed by this page.
  ///
  /// Overriding this method is an alternative to supplying the explicit builder
  /// function in the constructor.
  @protected
  Component build() {
    assert(
      _builder != null,
      'Either provide `builder` in the constructor, or override the build() '
      'method',
    );
    return _builder!();
  }

  /// Completely stops time for the managed page.
  ///
  /// When the time is stopped, the [updateTree] method of the page is not
  /// called at all, which can save computational resources. However, this also
  /// means that the lifecycle events on the page will not be processed, and
  /// therefore no components will be able to be added or removed from the
  /// page.
  void stopTime() => timeScale = 0;

  /// Resumes normal time progression for the page, if it was previously slowed
  /// down or stopped.
  void resumeTime() => timeScale = 1.0;

  /// Applies the provided [Decorator] to the page.
  ///
  /// Render effects should not be confused with regular [Effect]s. Examples of
  /// the render effects include: whole-page blur, convert into grayscale,
  /// apply color tint, etc.
  void addRenderEffect(Decorator effect) => _renderEffect.addLast(effect);

  /// Removes current [Decorator], is any.
  void removeRenderEffect() => _renderEffect.removeLast();

  //#region Implementation methods

  /// If true, the page must be rendered normally. If false, the page should
  /// not be rendered, because it is completely obscured by another route which
  /// is on top of it. This variable is set by the [RouterComponent].
  @internal
  bool isRendered = true;

  /// The page that was built and is now owned by this route. This page will
  /// also be added as a child component.
  Component? _page;

  /// The loadingPage that was built and is now owned by this route. The
  /// [_loadingPage] will also be added as a child component.
  Component? _loadingPage;

  /// Additional visual effect that may be applied to the page during rendering.
  final Decorator _renderEffect;

  /// Invoked by the [RouterComponent] when this route is pushed to the top
  /// of the navigation stack.
  @internal
  void didPush(Route? previousRoute) {
    _page ??= build();
    (_loadingBuilder != null) ? _addLoadingPage() : _page!.addToParent(this);
    onPush(previousRoute);
  }

  /// Adds the [_loadingPage] to the parent and invoked by [didPush] , when
  /// [_loadingBuilder] is specified
  Future<void> _addLoadingPage() async {
    _loadingPage ??= _loadingBuilder!()..addToParent(this);
    await _loadingPage!.loaded;
    await add(_page!);
    await _page!.loaded;
    _loadingPage!.removeFromParent();
  }

  /// Invoked by the [RouterComponent] when this route is popped off the top
  /// of the navigation stack.
  /// If [maintainState] is false, the page component rendered by this route
  /// is not retained when the route it popped.
  @internal
  void didPop(Route nextRoute) {
    onPop(nextRoute);
    if (!maintainState) {
      _page?.removeFromParent();
      _page = null;
    }
  }

  @override
  void renderTree(Canvas canvas) {
    if (isRendered) {
      _renderEffect.applyChain(super.renderTree, canvas);
    }
  }

  @override
  void updateTree(double dt) {
    if (timeScale > 0) {
      super.updateTree(dt);
    }
  }

  @override
  Iterable<Component> componentsAtLocation<T>(
    T locationContext,
    List<T>? nestedContexts,
    T? Function(CoordinateTransform, T) transformContext,
    bool Function(Component, T) checkContains,
  ) {
    if (isRendered) {
      return super.componentsAtLocation(
        locationContext,
        nestedContexts,
        transformContext,
        checkContains,
      );
    } else {
      return const Iterable<Component>.empty();
    }
  }

  //#endregion
}
