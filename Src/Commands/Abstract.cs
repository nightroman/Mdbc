
/* Copyright 2011-2014 Roman Kuzmin
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

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
		protected virtual void WriteException(Exception exception, object target)
		{
			WriteError(new ErrorRecord(exception, "Mdbc", ErrorCategory.NotSpecified, target));
		}
	}
}
