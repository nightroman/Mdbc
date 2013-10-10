
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

using System;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Get, "MdbcData", DefaultParameterSetName = NAll)]
	public sealed class GetDataCommand : AbstractCollectionCommand
	{
		const string NAll = "All";
		const string NDistinct = "Distinct";
		const string NCount = "Count";
		const string NCursor = "Cursor";
		const string NRemove = "Remove";
		const string NUpdate = "Update";
		
		[Parameter(Position = 0)]
		public object Query { get { return null; } set { _Query = Actor.ObjectToQuery(value); } }
		IMongoQuery _Query;
		
		[Parameter(Mandatory = true, ParameterSetName = NDistinct)]
		public string Distinct { get; set; }
		
		[Parameter(Mandatory = true, ParameterSetName = NCount)]
		public SwitchParameter Count { get; set; }
		
		[Parameter(Mandatory = true, ParameterSetName = NCursor)]
		public SwitchParameter Cursor { get; set; }
		
		[Parameter(Mandatory = true, ParameterSetName = NRemove)]
		public SwitchParameter Remove { get; set; }
		
		[Parameter(Mandatory = true, ParameterSetName = NUpdate)]
		public object Update { get { return null; } set { _Update = Actor.ObjectToUpdate(value); } }
		IMongoUpdate _Update;
		
		[Parameter(ParameterSetName = NUpdate)]
		public SwitchParameter New { get; set; }
		
		[Parameter(ParameterSetName = NUpdate)]
		public SwitchParameter Add { get; set; }
		
		[Parameter(ParameterSetName = NAll)]
		[Parameter(ParameterSetName = NCount)]
		[Parameter(ParameterSetName = NCursor)]
		[Parameter(ParameterSetName = NRemove)]
		[Parameter(ParameterSetName = NUpdate)]
		public QueryFlags Modes { get; set; }
		
		[Parameter(ParameterSetName = NAll)]
		[Parameter(ParameterSetName = NCount)]
		[Parameter(ParameterSetName = NCursor)]
		public int First { get; set; }
		
		[Parameter(ParameterSetName = NAll)]
		[Parameter(ParameterSetName = NCount)]
		[Parameter(ParameterSetName = NCursor)]
		public int Last { get; set; }
		
		[Parameter(ParameterSetName = NAll)]
		[Parameter(ParameterSetName = NCount)]
		[Parameter(ParameterSetName = NCursor)]
		public int Skip { get; set; }
		
		[Parameter(ParameterSetName = NAll)]
		[Parameter(ParameterSetName = NCursor)]
		[Parameter(ParameterSetName = NUpdate)]
		public string[] Property { get; set; }
		
		[Parameter(ParameterSetName = NAll)]
		[Parameter(ParameterSetName = NCursor)]
		[Parameter(ParameterSetName = NRemove)]
		[Parameter(ParameterSetName = NUpdate)]
		public object[] SortBy { get { return null; } set { _SortBy = Actor.ObjectsToSortBy(value); } }
		IMongoSortBy _SortBy;
		
		[Parameter(ParameterSetName = NAll)]
		[Parameter(ParameterSetName = NCursor)]
		public Type As { get; set; }
		
		[Parameter(ParameterSetName = NAll)]
		[Parameter(ParameterSetName = NCursor)]
		public SwitchParameter AsCustomObject { get; set; }
		
		void DoCount()
		{
			WriteObject(Collection.Count(_Query));
		}
		void DoDistinct()
		{
			var data = Collection.Distinct(Distinct, _Query);
			foreach (var it in data)
				WriteObject(Actor.ToObject(it));
		}
		void DoModified(FindAndModifyResult result)
		{
			if (result.ModifiedDocument != null)
				WriteObject(new Dictionary(result.ModifiedDocument));

			if (!result.Ok)
				WriteError(new ErrorRecord(new RuntimeException(result.ErrorMessage), "Driver", ErrorCategory.InvalidResult, result));
		}
		void DoRemove()
		{
			var result = Collection.FindAndRemove(_Query, _SortBy);
			DoModified(result);
		}
		void DoUpdate()
		{
			var result = Collection.FindAndModify(_Query, _SortBy, _Update, New, Add);
			DoModified(result);
		}
		Type GetDocumentType()
		{
			return AsCustomObject ? typeof(PSObject) : As ?? typeof(BsonDocument);
		}
		protected override void BeginProcessing()
		{
			try
			{
				switch (ParameterSetName)
				{
					case NCount:
						if (First > 0 || Skip > 0)
							break;
						DoCount();
						return;

					case NDistinct:
						DoDistinct();
						return;

					case NRemove:
						DoRemove();
						return;

					case NUpdate:
						DoUpdate();
						return;
				}

				var documentType = GetDocumentType();
				var cursor = Collection.FindAs(documentType, _Query);

				if (Modes != QueryFlags.None)
					cursor.SetFlags(Modes);

				if (Last > 0)
				{
					Skip = (int)Collection.Count(_Query) - Skip - Last;
					First = Last;
					if (Skip < 0)
					{
						First += Skip;
						if (First <= 0)
						{
							if (Count)
								WriteObject(0);
							return;
						}
						Skip = 0;
					}
				}

				if (First > 0)
					cursor.SetLimit(First);

				if (Skip > 0)
					cursor.SetSkip(Skip);

				if (Count)
				{
					WriteObject(cursor.Size());
					return;
				}

				if (_SortBy != null)
					cursor.SetSortOrder(_SortBy);

				if (Property != null)
					cursor.SetFields(Property);

				if (Cursor)
				{
					WriteObject(cursor);
					return;
				}

				if (documentType == typeof(BsonDocument))
				{
					foreach (BsonDocument bson in cursor)
						WriteObject(new Dictionary(bson));
				}
				else
				{
					if (documentType == typeof(PSObject))
						PSObjectSerializer.Register();

					WriteObject(cursor, true);
				}
			}
			catch (MongoException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
