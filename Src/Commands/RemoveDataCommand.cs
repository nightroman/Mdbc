
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Remove, "MdbcData")]
	public sealed class RemoveDataCommand : AbstractWriteCommand
	{
		//_131121_104038 Not mandatory to avoid prompts. Manual null check is used instead for consistent messages.
		// String values from prompts might imply unexpected results.
		[Parameter(Position = 0, ValueFromPipeline = true)]
		public object Query { get { return null; } set { _Query = Actor.ObjectToQuery(value); } }
		IMongoQuery _Query;

		//_131122_164305
		[Parameter]
		public SwitchParameter One { get; set; }

		RemoveFlags _Flags;

		protected override void BeginProcessing()
		{
			if (One)
				_Flags |= RemoveFlags.Single;
		}
		protected override void ProcessRecord()
		{
			if (_Query == null) throw new PSArgumentException(TextParameterQuery); //_131121_104038

			try
			{
				WriteResult(TargetCollection.Remove(_Query, _Flags, WriteConcern, Result));
			}
			catch (MongoException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
