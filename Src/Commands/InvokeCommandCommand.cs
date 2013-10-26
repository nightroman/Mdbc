
/* Copyright 2011-2013 Roman Kuzmin
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
		public PSObject Command
		{
			get { return null; }
			set
			{
				_CommandName = value.BaseObject as string;
				if (_CommandName == null)
				{
					var dictionary = value.BaseObject as IDictionary;
					if (dictionary != null)
						_CommandDocument = new CommandDocument(Actor.ToBsonDocument(dictionary));
					else
						throw new PSArgumentException("Invalid command object type.");
				}
			}
		}
		string _CommandName;
		CommandDocument _CommandDocument;
		
		[Parameter(Position = 1)]
		public object Value { get; set; }
		
		protected override void BeginProcessing()
		{
			if (_CommandDocument == null)
			{
				if (Value == null)
					_CommandDocument = new CommandDocument(_CommandName, 1);
				else
					_CommandDocument = new CommandDocument(_CommandName, Actor.ToBsonValue(Value));
			}

			try
			{
				var result = Database.RunCommand(_CommandDocument);
				WriteObject(new Dictionary(result.Response));
			}
			catch (MongoCommandException ex)
			{
				WriteException(ex, null);
				WriteObject(new Dictionary(ex.CommandResult.Response));
			}
		}
	}
}
