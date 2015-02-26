
/* Copyright 2011-2015 Roman Kuzmin
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

using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsData.Update, "MdbcData")]
	public sealed class UpdateDataCommand : AbstractWriteCommand
	{
		//_131121_104038
		[Parameter(Position = 0)]
		public object Update { get { return null; } set { _Update = Actor.ObjectToUpdate(value, x => _UpdateError = x); } } //_131102_111738
		IMongoUpdate _Update;
		string _UpdateError;

		//_131121_104038
		[Parameter(Position = 1, ValueFromPipeline = true)]
		public object Query { get { return null; } set { _Input = value; _Query = Actor.ObjectToQuery(value); } }
		IMongoQuery _Query;
		object _Input;

		[Parameter]
		public SwitchParameter Add { get; set; }

		//_131122_164305 Ideally Remove and Update should do just All or provide sorting for One to
		// avoid unpredictable. But they do not. Also, they have different defaults. Mdbc follows
		// the driver, partially due to simpler syntax allowed on default update (@{x=..}). Thus,
		// if Mdbc makes All the only or default then simple syntax is either gone or not default.
		[Parameter]
		public SwitchParameter All { get; set; }

		UpdateFlags _Flags;

		protected override void BeginProcessing()
		{
			if (_Update == null) throw new PSArgumentException(_UpdateError ?? TextParameterUpdate); //_131102_111738

			if (Add)
				_Flags |= UpdateFlags.Upsert;

			if (All)
				_Flags |= UpdateFlags.Multi;
		}
		protected override void ProcessRecord()
		{
			if (_Query == null) throw new PSArgumentException(TextParameterQuery); //_131121_104038

			try
			{
				WriteResult(TargetCollection.Update(_Query, _Update, _Flags, WriteConcern, Result));
			}
			catch (MongoException ex)
			{
				WriteException(ex, _Input);
			}
		}
	}
}
