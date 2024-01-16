
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Management.Automation;

namespace Mdbc.Commands;

[Cmdlet(VerbsCommon.Remove, "MdbcData"), OutputType(typeof(DeleteResult))]
public sealed class RemoveDataCommand : AbstractCollectionCommand
{
	[Parameter(Position = 0, ValueFromPipeline = true)]
	public object Filter
	{
		get => _Filter;
		set { _Filter = value; _FilterSet = true; }
	}
	object _Filter;
	bool _FilterSet;

	[Parameter]
	public SwitchParameter Many { get; set; }

	[Parameter]
	public SwitchParameter Result { get; set; }

	protected override void BeginProcessing()
	{
		if (MyInvocation.ExpectingInput)
		{
			if (_FilterSet)
				throw new PSArgumentException(Res.ParameterFilter2);

			if (Many)
				throw new PSArgumentException("Parameter Many is not supported with pipeline input.");
		}
		else
		{
			if (_Filter == null)
				throw new PSArgumentException(Res.ParameterFilter1);
		}
	}

	protected override void ProcessRecord()
	{
		try
		{
			FilterDefinition<BsonDocument> filter;
			if (MyInvocation.ExpectingInput)
			{
				if (_Filter == null)
					throw new PSArgumentException(Res.InputDocNull);

				filter = Api.FilterDefinitionOfInputId(_Filter);
			}
			else
			{
				try
				{
					filter = Api.FilterDefinition(_Filter);
				}
				catch(Exception exn)
				{
					var text = $"Parameter Filter: {exn.Message}";
					throw new PSArgumentException(text, exn);
				}

				if (filter == null)
					throw new PSArgumentException(Res.ParameterFilter1);
			}

			DeleteResult result;
			if (Many)
			{
				result = Collection.DeleteMany(Session, filter);
			}
			else
			{
				result = Collection.DeleteOne(Session, filter);
			}

			if (Result)
				WriteObject(result);
		}
		catch (MongoException ex)
		{
			WriteException(ex, null);
		}
	}
}
