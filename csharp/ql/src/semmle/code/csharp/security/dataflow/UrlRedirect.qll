/**
 * Provides a taint-tracking configuration for reasoning about unvalidated URL redirect problems.
 */
import csharp

module UrlRedirect {
  import semmle.code.csharp.dataflow.flowsources.Remote
  import semmle.code.csharp.controlflow.Guards
  import semmle.code.csharp.frameworks.system.Web
  import semmle.code.csharp.frameworks.system.web.Mvc
  import semmle.code.csharp.security.Sanitizers

  /**
   * A data flow source for unvalidated URL redirect vulnerabilities.
   */
  abstract class Source extends DataFlow::Node { }

  /**
   * A data flow sink for unvalidated URL redirect vulnerabilities.
   */
  abstract class Sink extends DataFlow::ExprNode { }

  /**
   * A sanitizer for unvalidated URL redirect vulnerabilities.
   */
  abstract class Sanitizer extends DataFlow::ExprNode { }

  /**
   * A taint-tracking configuration for reasoning about unvalidated URL redirect vulnerabilities.
   */
  class TaintTrackingConfiguration extends TaintTracking::Configuration {
    TaintTrackingConfiguration() {
      this = "UrlRedirect"
    }

    override
    predicate isSource(DataFlow::Node source) {
      source instanceof Source
    }

    override
    predicate isSink(DataFlow::Node sink) {
      sink instanceof Sink
    }

    override
    predicate isSanitizer(DataFlow::Node node) {
      node instanceof Sanitizer
    }
  }

  /** A source of remote user input. */
  class RemoteSource extends Source {
    RemoteSource() {
      this instanceof RemoteFlowSource
    }
  }

  /**
   * A URL argument to a call to `HttpResponse.Redirect()` or `Controller.Redirect()`, that is a
   * sink for URL redirects.
   */
  class RedirectSink extends Sink {
    RedirectSink() {
      exists(MethodCall mc |
        mc.getTarget() = any(SystemWebHttpResponseClass response).getRedirectMethod() or
        mc.getTarget() = any(SystemWebMvcControllerClass response).getARedirectMethod()
        |
        // Redirect uses the parameter name url
        this.getExpr() = mc.getArgumentForName("url") or
        // RedirectToAction
        this.getExpr() = mc.getArgumentForName("actionName") or
        // RedirectToRoute
        this.getExpr() = mc.getArgumentForName("routeName")
      )
    }
  }

  /**
   * A value argument to a call to `AddHeader` or `AppendHeader` that adds the `Location`.
   */
  class LocationHeaderSink extends Sink {
    LocationHeaderSink() {
      exists(MethodCall call |
        call.getTarget() = any(SystemWebHttpResponseClass r).getAppendHeaderMethod() or
        call.getTarget() = any(SystemWebHttpResponseClass r).getAddHeaderMethod() |
        call.getArgumentForName("name").getValue() = "Location" and
        this.getExpr() = call.getArgumentForName("value")
      )
    }
  }

  /**
   * A path argument to a call to `HttpServerUtility.Transfer`.
   */
  class HttpServerTransferSink extends Sink {
    HttpServerTransferSink() {
      exists(MethodCall call |
        call.getTarget() = any(SystemWebHttpServerUtility s).getTransferMethod() |
        this.getExpr() = call.getArgumentForName("path")
      )
    }
  }

  /**
   * A URL argument to a call to `UrlHelper.isLocalUrl()` that is a sanitizer for URL redirects.
   */
  class IsLocalUrlSanitizer extends Sanitizer {
    IsLocalUrlSanitizer() {
      exists(MethodCall mc |
        mc.getTarget().hasName("IsLocalUrl") |
        this.getExpr().(GuardedExpr).isGuardedBy(mc, mc.getArgument(0), true)
      )
    }
  }

  /**
   * A call to the getter of the RawUrl property, whose value is considered to be safe for URL
   * redirects.
   */
  class RawUrlSanitizer extends Sanitizer {
    RawUrlSanitizer() {
      this.getExpr() = any(SystemWebHttpRequestClass r).getRawUrlProperty().getGetter().getACall()
    }
  }

  /**
   * A string concatenation expression, where the left hand side contains the character "?".
   *
   * This is considered as sanitizing the overall expression, because the attacker can then
   * only control the query string parameters, rather than the location itself. In the majority of
   * cases, this will only allow the attacker to redirect the user to a link they could have already
   * redirected them to.
   */
  class ConcatenationSanitizer extends Sanitizer {
    ConcatenationSanitizer() {
      this.getType() instanceof StringType and
      this.getExpr().(AddExpr).getLeftOperand().getValue().matches("%?%")
    }
  }

  /** A call to an URL encoder. */
  class UrlEncodeSanitizer extends Sanitizer {
    UrlEncodeSanitizer() {
      this.getExpr() instanceof UrlSanitizedExpr
    }
  }

  private class SimpleTypeSanitizer extends Sanitizer, SimpleTypeSanitizedExpr { }

  private class GuidSanitizer extends Sanitizer, GuidSanitizedExpr { }
}