
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Threading;
using System.Threading.Tasks;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Watch, "MdbcChange"), OutputType(typeof(IAsyncCursor<object>))]
	public sealed class WatchChangeCommand : AbstractSessionCommand
	{
		[Parameter(Position = 0)]
		public object Pipeline { set { if (value != null) _Pipeline = Api.PipelineDefinition<ChangeStreamDocument<BsonDocument>, BsonDocument>(value); } }
		PipelineDefinition<ChangeStreamDocument<BsonDocument>, BsonDocument> _Pipeline;

		[Parameter(Mandatory = true, ParameterSetName = "Collection")]
		public IMongoCollection<BsonDocument> Collection { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = "Database")]
		public IMongoDatabase Database { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = "Client")]
		public IMongoClient Client { get; set; }

		[Parameter]
		public ChangeStreamOptions Options { get; set; }

		[Parameter]
		public object As { set { _As.Set(value); } }
		readonly ParameterAs _As = new ParameterAs();

		protected override IMongoClient MyClient
		{
			get
			{
				if (Collection != null)
					return Collection.Database.Client;
				else if (Database != null)
					return Database.Client;
				else
					return Client;
			}
		}

		[System.Diagnostics.CodeAnalysis.SuppressMessage("Reliability", "CA2000:Dispose objects before losing scope")]
		protected override void BeginProcessing()
		{
			if (_Pipeline == null)
				_Pipeline = new List<BsonDocument>();

			IChangeStreamCursor<BsonDocument> cursor;
			if (Collection != null)
				cursor = Collection.Watch(Session, _Pipeline, Options);
			else if (Database != null)
				cursor = Database.Watch(Session, _Pipeline, Options);
			else
				cursor = Client.Watch(Session, _Pipeline, Options);

			WriteObject(new ChangeStreamCursor(cursor, _As.Type));
		}
	}

	sealed class ChangeStreamCursor : IDisposable, IAsyncCursor<object>
	{
		readonly IChangeStreamCursor<BsonDocument> _cursor;
		readonly Func<BsonDocument, object> _convert;
		internal ChangeStreamCursor(IChangeStreamCursor<BsonDocument> cursor, Type outputType)
		{
			_cursor = cursor;
			_convert = Actor.ConvertDocument(outputType);
		}
		public void Dispose()
		{
			_cursor.Dispose();
		}
		public IEnumerable<object> Current
		{
			get
			{
				return _cursor.Current.Select(_convert);
			}
		}
		public bool MoveNext(CancellationToken cancellationToken = default)
		{
			return _cursor.MoveNext(cancellationToken);
		}
		public Task<bool> MoveNextAsync(CancellationToken cancellationToken = default)
		{
			return _cursor.MoveNextAsync(cancellationToken);
		}
	}
}
