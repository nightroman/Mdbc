
using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands;

[Cmdlet(VerbsCommon.Get, "MdbcData", DefaultParameterSetName = nsAll), OutputType(typeof(Dictionary))]
public sealed class GetDataCommand : AbstractCollectionCommand
{
	const string nsAll = "All";
	const string nsCount = "Count";
	const string nsDistinct = "Distinct";
	const string nsRemove = "Remove";
	const string nsSet = "Set";
	const string nsUpdate = "Update";

	[Parameter(Position = 0)]
	public object Filter { set => _Filter = Api.FilterDefinition(value); }
	FilterDefinition<BsonDocument> _Filter = Builders<BsonDocument>.Filter.Empty;

	[Parameter(Mandatory = true, ParameterSetName = nsDistinct)]
	public string Distinct { get; set; }

	[Parameter(Mandatory = true, ParameterSetName = nsCount)]
	public SwitchParameter Count { get; set; }

	[Parameter(Mandatory = true, ParameterSetName = nsRemove)]
	public SwitchParameter Remove { get; set; }

	[Parameter(Mandatory = true, ParameterSetName = nsSet)]
	public object Set { set => _Set = Actor.ToBsonDocument(value); }
	BsonDocument _Set;

	[Parameter(Mandatory = true, ParameterSetName = nsUpdate)]
	public object Update { set => _Update = Api.UpdateDefinition(value); }
	UpdateDefinition<BsonDocument> _Update;

	[Parameter(ParameterSetName = nsSet)]
	[Parameter(ParameterSetName = nsUpdate)]
	public SwitchParameter New { get; set; }

	[Parameter(ParameterSetName = nsSet)]
	[Parameter(ParameterSetName = nsUpdate)]
	public SwitchParameter Add { get; set; }

	[Parameter(ParameterSetName = nsAll)]
	[Parameter(ParameterSetName = nsCount)]
	public long First { get; set; }

	[Parameter(ParameterSetName = nsAll)]
	public long Last { get; set; }

	[Parameter(ParameterSetName = nsAll)]
	[Parameter(ParameterSetName = nsCount)]
	public long Skip { get; set; }

	[Parameter(ParameterSetName = nsAll)]
	[Parameter(ParameterSetName = nsRemove)]
	[Parameter(ParameterSetName = nsSet)]
	[Parameter(ParameterSetName = nsUpdate)]
	public object Project { set => _Project.Set(value); }
	readonly ParameterProject _Project = new();

	[Parameter(ParameterSetName = nsAll)]
	[Parameter(ParameterSetName = nsRemove)]
	[Parameter(ParameterSetName = nsSet)]
	[Parameter(ParameterSetName = nsUpdate)]
	public object Sort { set => _Sort = Api.SortDefinition(value); }
	SortDefinition<BsonDocument> _Sort;

	[Parameter(ParameterSetName = nsAll)]
	[Parameter(ParameterSetName = nsRemove)]
	[Parameter(ParameterSetName = nsSet)]
	[Parameter(ParameterSetName = nsUpdate)]
	public object As { set => _As.Set(value); }
	readonly ParameterAs _As = new();

	void DoDistinct()
	{
		FieldDefinition<BsonDocument, BsonValue> field = Distinct;
		foreach (var it in Collection.Distinct(Session, field, _Filter).ToEnumerable())
			WriteObject(Actor.ToObject(it));
	}

	void DoRemove()
	{
		var document = Collection.MyFindOneAndDelete(Session, _Filter, _Sort, _Project.Get(_As));
		if (document != null)
		{
			var convert = Actor.ConvertDocument(_As.Type);
			WriteObject(convert(document));
		}
	}

	void DoSet()
	{
		var document = Collection.MyFindOneAndReplace(Session, _Filter, _Set, _Sort, _Project.Get(_As), New, Add);
		if (document != null)
		{
			var convert = Actor.ConvertDocument(_As.Type);
			WriteObject(convert(document));
		}
	}

	void DoUpdate()
	{
		var document = Collection.MyFindOneAndUpdate(Session, _Filter, _Update, _Sort, _Project.Get(_As), New, Add);
		if (document != null)
		{
			var convert = Actor.ConvertDocument(_As.Type);
			WriteObject(convert(document));
		}
	}

	bool DoLast()
	{
		if (Last <= 0)
			return false;

		Skip = Collection.CountDocuments(Session, _Filter) - Skip - Last;
		First = Last;
		if (Skip >= 0)
			return false;

		First += Skip;
		if (First <= 0)
			return true;

		Skip = 0;
		return false;
	}

	protected override void BeginProcessing()
	{
		if (First > 0 && Last > 0)
			throw new PSArgumentException("Parameters First and Last cannot be specified together.");

		try
		{
			switch (ParameterSetName)
			{
				case nsCount:
					WriteObject(Collection.MyCount(Session, _Filter, Skip, First));
					return;

				case nsDistinct:
					DoDistinct();
					return;

				case nsRemove:
					DoRemove();
					return;

				case nsSet:
					DoSet();
					return;

				case nsUpdate:
					DoUpdate();
					return;
			}

			// Last -> First and Skip
			if (DoLast())
				return;

			//_131018_160000 Do not use WriteObject(.., true), that seems to take a lot more memory
			var convert = Actor.ConvertDocument(_As.Type);
			foreach (var document in Collection.MyFind(Session, _Filter, _Sort, Skip, First, _Project.Get(_As)))
			{
				WriteObject(convert(document));
			}
		}
		catch (MongoException ex)
		{
			WriteException(ex, null);
		}
	}
}
