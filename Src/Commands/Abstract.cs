
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Management.Automation;

namespace Mdbc.Commands
{
	public abstract class Abstract : PSCmdlet
	{
		public const string TextParameterQuery = "Parameter Query must be specified and cannot be null.";
		public const string TextParameterUpdate = "Parameter Update must be specified and cannot be null.";

		protected Abstract()
		{
			Actor.Register();
		}
		protected void WriteException(Exception exception, object target)
		{
			WriteError(new ErrorRecord(exception, "Mdbc", ErrorCategory.NotSpecified, target));
		}
	}
}
