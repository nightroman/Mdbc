
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

using System.Linq;
using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Get, "MdbcData", DefaultParameterSetName = nsAll)]
	public sealed class GetDataCommand : AbstractCollectionCommand
	{
		const string nsAll = "All";
		const string nsDistinct = "Distinct";
		const string nsCount = "Count";
		const string nsCursor = "Cursor";
		const string nsRemove = "Remove";
		const string nsUpdate = "Update";

		[Parameter(Position = 0)]
		public object Query { get { return null; } set { _Query = Actor.ObjectToQuery(value); } }
		IMongoQuery _Query;

		[Parameter(Mandatory = true, ParameterSetName = nsDistinct)]
		public string Distinct { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsCount)]
		public SwitchParameter Count { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsCursor)]
		public SwitchParameter Cursor { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsRemove)]
		public SwitchParameter Remove { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = nsUpdate)]
		public object Update { get { return null; } set { _Update = Actor.ObjectToUpdate(value, null); } }
		IMongoUpdate _Update;

		[Parameter(ParameterSetName = nsUpdate)]
		public SwitchParameter New { get; set; }

		[Parameter(ParameterSetName = nsUpdate)]
		public SwitchParameter Add { get; set; }

		[Parameter(ParameterSetName = nsAll)]
		[Parameter(ParameterSetName = nsCount)]
		[Parameter(ParameterSetName = nsCursor)]
		[Parameter(ParameterSetName = nsRemove)]
		[Parameter(ParameterSetName = nsUpdate)]
		public QueryFlags Modes { get; set; }

		[Parameter(ParameterSetName = nsAll)]
		[Parameter(ParameterSetName = nsCount)]
		[Parameter(ParameterSetName = nsCursor)]
		public int First { get; set; }

		[Parameter(ParameterSetName = nsAll)]
		[Parameter(ParameterSetName = nsCount)]
		[Parameter(ParameterSetName = nsCursor)]
		public int Last { get; set; }

		[Parameter(ParameterSetName = nsAll)]
		[Parameter(ParameterSetName = nsCount)]
		[Parameter(ParameterSetName = nsCursor)]
		public int Skip { get; set; }

		[Parameter(ParameterSetName = nsAll)]
		[Parameter(ParameterSetName = nsCursor)]
		[Parameter(ParameterSetName = nsUpdate)]
		public object[] Property { get { return null; } set { _Fields = Actor.ObjectsToFields(value); } }
		IMongoFields _Fields;

		[Parameter(ParameterSetName = nsAll)]
		[Parameter(ParameterSetName = nsCursor)]
		[Parameter(ParameterSetName = nsRemove)]
		[Parameter(ParameterSetName = nsUpdate)]
		public object[] SortBy { get { return null; } set { _SortBy = Actor.ObjectsToSortBy(value); } }
		IMongoSortBy _SortBy;

		[Parameter(ParameterSetName = nsAll)]
		[Parameter(ParameterSetName = nsCursor)]
		[Parameter(ParameterSetName = nsRemove)]
		[Parameter(ParameterSetName = nsUpdate)]
		public PSObject As { get { return null; } set { _ParameterAs = new ParameterAs(value); } }
		ParameterAs _ParameterAs;

		void DoCount()
		{
			if (FileCollection == null)
				WriteObject(MongoCollection.Count(_Query));
			else
				WriteObject(FileCollection.Count(_Query));
		}
		void DoDistinct()
		{
			var data = FileCollection == null ? MongoCollection.Distinct(Distinct, _Query) : FileCollection.Distinct(Distinct, _Query);
			foreach (var it in data)
				WriteObject(Actor.ToObject(it));
		}
		void DoModified(FindAndModifyResult result)
		{
			if (result.ModifiedDocument != null)
			{
				var documentAs = _ParameterAs ?? new ParameterAs(null);
				WriteObject(result.GetModifiedDocumentAs(documentAs.Type));
			}

			if (!result.Ok)
				WriteError(new ErrorRecord(new RuntimeException(result.ErrorMessage), "Driver", ErrorCategory.InvalidResult, result));
		}
		void DoRemove()
		{
			if (FileCollection == null)
			{
				DoModified(MongoCollection.FindAndRemove(_Query, _SortBy));
			}
			else
			{
				var documentAs = _ParameterAs ?? new ParameterAs(null);
				var document = FileCollection.FindAndRemoveAs(documentAs.Type, _Query, _SortBy);
				if (document != null)
					WriteObject(document);
			}
		}
		void DoUpdate()
		{
			if (FileCollection == null)
			{
				var result = MongoCollection.FindAndModify(_Query, _SortBy, _Update, _Fields, New, Add);
				DoModified(result);
			}
			else
			{
				var documentAs = _ParameterAs ?? new ParameterAs(null);
				var document = FileCollection.FindAndModifyAs(documentAs.Type, _Query, _SortBy, _Update, _Fields, New, Add);
				if (document != null)
					WriteObject(document);
			}
		}
		bool DoLast()
		{
			if (Last <= 0)
				return false;

			Skip = (int)((FileCollection == null ? MongoCollection.Count(_Query) : FileCollection.Count(_Query)) - Skip - Last);
			First = Last;
			if (Skip >= 0)
				return false;

			First += Skip;
			if (First <= 0)
			{
				if (Count)
					WriteObject(0);
				return true;
			}
			Skip = 0;
			return false;
		}
		void DoFileCollection()
		{
			if (Cursor) ThrowNotImplementedForFiles("Parameter Cursor");

			var iter = FileCollection.FindAs(_ParameterAs.Type, _Query, _SortBy, First, Skip, _Fields); //TODO to use cursor and fields in it
			if (Count)
			{
				WriteObject(iter.Count());
			}
			else
			{
				foreach (var document in iter)
					WriteObject(document);
			}
		}
		void DoMongoCollection()
		{
			var cursor = MongoCollection.FindAs(_ParameterAs.Type, _Query);

			if (Modes != QueryFlags.None)
				cursor.SetFlags(Modes);

			if (Skip > 0)
				cursor.SetSkip(Skip);

			if (First > 0)
				cursor.SetLimit(First);

			if (Count)
			{
				WriteObject(cursor.Size());
				return;
			}

			if (_SortBy != null)
				cursor.SetSortOrder(_SortBy);

			if (_Fields != null)
				cursor.SetFields(_Fields);

			//_131018_160000 Do not use WriteObject(.., true), that seems to take a lot more memory
			if (Cursor)
				WriteObject(cursor);
			else
				foreach (var it in cursor)
					WriteObject(it);
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
						if (First > 0 || Skip > 0 || Last > 0)
							break;
						DoCount();
						return;

					case nsDistinct:
						DoDistinct();
						return;

					case nsRemove:
						DoRemove();
						return;

					case nsUpdate:
						DoUpdate();
						return;
				}

				// ensure As
				_ParameterAs = _ParameterAs ?? new ParameterAs(null);

				// Last -> First and Skip
				if (DoLast())
					return;

				// do
				if (FileCollection == null)
					DoMongoCollection();
				else
					DoFileCollection();
			}
			catch (MongoException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
