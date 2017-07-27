
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Driver;
using System.Management.Automation;

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
