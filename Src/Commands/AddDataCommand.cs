
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace Mdbc.Commands;

[Cmdlet(VerbsCommon.Add, "MdbcData")]
public sealed class AddDataCommand : AbstractCollectionCommand
{
	[Parameter(Position = 0, ValueFromPipeline = true)]
	public object InputObject { get; set; }

	[Parameter]
	public object Id { get; set; }

	[Parameter]
	public SwitchParameter NewId { get; set; }

	[Parameter]
	public ScriptBlock Convert { get; set; }

	[Parameter]
	public SwitchParameter Many { get; set; }

	[Parameter]
	public object[] Property { set { if (value == null) throw new PSArgumentNullException(nameof(value)); _Selectors = Selector.Create(value); } }
	IList<Selector> _Selectors;

	bool _done;

	List<BsonDocument> _manyDocuments;

	protected override void BeginProcessing()
	{
		if (Many)
			_manyDocuments = [];

		if (!MyInvocation.ExpectingInput)
		{
			var collection = LanguagePrimitives.GetEnumerable(InputObject);
			if (collection != null)
			{
				_done = true;
				foreach (var value in collection)
					Process(value);
			}
		}
	}

	protected override void ProcessRecord()
	{
		if (!_done)
			Process(InputObject);
	}

	void Process(object InputObject)
	{
		if (InputObject == null)
			return;

		try
		{
			// new document or none yet
			var document = DocumentInput.NewDocumentWithId(NewId, Id, InputObject);

			document = Actor.ToBsonDocument(document, InputObject, Convert, _Selectors);

			if (Many)
				_manyDocuments.Add(document);
			else
				Collection.InsertOne(Session, document);
		}
		catch (ArgumentException ex)
		{
			WriteError(DocumentInput.NewErrorRecordBsonValue(ex, InputObject));
		}
		catch (MongoException ex)
		{
			WriteException(ex, InputObject);
		}
	}

	protected override void EndProcessing()
	{
		if (Many)
		{
			try
			{
				Collection.InsertMany(Session, _manyDocuments);
			}
			catch (MongoException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
