
/* Copyright 2011-2012 Roman Kuzmin
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

using System.Collections;
using System.Management.Automation;
using MongoDB.Driver;
namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Invoke, "MdbcCommand")]
	public sealed class InvokeCommandCommand : AbstractDatabaseCommand
	{
		[Parameter(Position = 0, Mandatory = true)]
		public PSObject Command { get; set; }
		[Parameter(Position = 1)]
		public object Value { get; set; }
		protected override void BeginProcessing()
		{
			CommandDocument document;
			var commandName = Command.BaseObject as string;
			if (commandName != null)
			{
				if (Value == null)
					document = new CommandDocument(commandName, 1);
				else
					document = new CommandDocument(commandName, Actor.ToBsonValue(Value));
			}
			else
			{
				var dictionary = Command.BaseObject as IDictionary;
				if (dictionary != null)
					document = new CommandDocument(dictionary);
				else
					throw new PSArgumentException("Invalid command type.", "Command");
			}

			var result = Database.RunCommand(document);
			WriteObject(new Dictionary(result.Response));
		}
	}
}
