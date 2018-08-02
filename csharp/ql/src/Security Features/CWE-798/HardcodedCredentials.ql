/**
 * @name Hard-coded credentials
 * @description Credentials are hard coded in the source code of the application.
 * @kind problem
 * @problem.severity error
 * @precision high
 * @id cs/hardcoded-credentials
 * @tags security
 *       external/cwe/cwe-259
 *       external/cwe/cwe-321
 *       external/cwe/cwe-798
 */
import csharp
private import semmle.code.csharp.security.dataflow.HardcodedCredentials::HardcodedCredentials

from TaintTrackingConfiguration c, Source source, Sink sink, string value
where c.hasFlow(source, sink)
  // Print the source value if it's available
  and if exists(source.asExpr().getValue()) then
    value = "The hard-coded value \"" + source.asExpr().getValue() + "\""
  else
    value = "This hard-coded value"
select source, value + " flows to " + sink.getSinkDescription() + ".", sink, sink.getSinkName(), sink.getSupplementaryElement(), sink.getSupplementaryElement().toString()