
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
		public object Update { get { return null; } set { _Update = Actor.ObjectToUpdate(value); } }
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
		public string[] Property { get; set; }

		[Parameter(ParameterSetName = nsAll)]
		[Parameter(ParameterSetName = nsCursor)]
		[Parameter(ParameterSetName = nsRemove)]
		[Parameter(ParameterSetName = nsUpdate)]
		public object[] SortBy { get { return null; } set { _SortBy = Actor.ObjectsToSortBy(value); } }
		IMongoSortBy _SortBy;

		[Parameter(ParameterSetName = nsAll)]
		[Parameter(ParameterSetName = nsCursor)]
		public PSObject As { get { return null; } set { _ParameterAs = new ParameterAs(value); } }
		ParameterAs _ParameterAs;

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
		protected override void BeginProcessing()
		{
			try
			{
				switch (ParameterSetName)
				{
					case nsCount:
						if (First > 0 || Skip > 0)
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

				var documentAs = _ParameterAs ?? new ParameterAs(null);
				var cursor = Collection.FindAs(documentAs.DeserializeType, _Query);

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

				//_131018_160000 Do not use WriteObject(.., true), it seems to take a lot more memory
				if (Cursor)
					WriteObject(cursor);
				else
					foreach(var it in cursor)
						WriteObject(it);
			}
			catch (MongoException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
