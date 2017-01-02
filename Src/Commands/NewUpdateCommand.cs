
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.Builders;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.New, "MdbcUpdate")]
	public sealed class NewUpdateCommand : Abstract
	{
		[Parameter]
		[ValidateNotNull]
		public PSObject[] AddToSet
		{
			get { return null; }
			set
			{
				_AddToSet = new UpdateBuilder();
				foreach (var e in Convert(value, Actor.ToBsonValue))
					_AddToSet.Combine(Update.AddToSet(e.Key, e.Value));
			}
		}
		UpdateBuilder _AddToSet;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] AddToSetEach
		{
			get { return null; }
			set
			{
				_AddToSetEach = new UpdateBuilder();
				foreach (var e in Convert(value, Actor.ToEnumerableBsonValue))
					_AddToSetEach.Combine(Update.AddToSetEach(e.Key, e.Value));
			}
		}
		UpdateBuilder _AddToSetEach;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] BitwiseAnd
		{
			get { return null; }
			set
			{
				_BitwiseAnd = new UpdateBuilder();
				foreach (var e in Convert(value, x => new IntLong(x)))
				{
					var n = e.Key;
					var x = e.Value;
					_BitwiseAnd.Combine(x.Int.HasValue ? Update.BitwiseAnd(n, x.Int.Value) : Update.BitwiseAnd(n, x.Long.Value));
				}
			}
		}
		UpdateBuilder _BitwiseAnd;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] BitwiseOr
		{
			get { return null; }
			set
			{
				_BitwiseOr = new UpdateBuilder();
				foreach (var e in Convert(value, x => new IntLong(x)))
				{
					var n = e.Key;
					var x = e.Value;
					_BitwiseOr.Combine(x.Int.HasValue ? Update.BitwiseOr(n, x.Int.Value) : Update.BitwiseOr(n, x.Long.Value));
				}
			}
		}
		UpdateBuilder _BitwiseOr;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] BitwiseXor
		{
			get { return null; }
			set
			{
				_BitwiseXor = new UpdateBuilder();
				foreach (var e in Convert(value, x => new IntLong(x)))
				{
					var n = e.Key;
					var x = e.Value;
					_BitwiseXor.Combine(x.Int.HasValue ? Update.BitwiseXor(n, x.Int.Value) : Update.BitwiseXor(n, x.Long.Value));
				}
			}
		}
		UpdateBuilder _BitwiseXor;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] Inc
		{
			get { return null; }
			set
			{
				_Inc = new UpdateBuilder();
				foreach (var e in Convert(value, x => new IntLongDouble(x)))
				{
					var n = e.Key;
					var x = e.Value;
					_Inc.Combine(x.Int.HasValue ? Update.Inc(n, x.Int.Value) : x.Long.HasValue ? Update.Inc(n, x.Long.Value) : Update.Inc(n, x.Double.Value));
				}
			}
		}
		UpdateBuilder _Inc;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] Mul
		{
			get { return null; }
			set
			{
				_Mul = new UpdateBuilder();
				foreach (var e in Convert(value, x => new IntLongDouble(x)))
				{
					var n = e.Key;
					var x = e.Value;
					_Mul.Combine(x.Int.HasValue ? Update.Mul(n, x.Int.Value) : x.Long.HasValue ? Update.Mul(n, x.Long.Value) : Update.Mul(n, x.Double.Value));
				}
			}
		}
		UpdateBuilder _Mul;

		[Parameter]
		[ValidateNotNull]
		public string[] PopFirst
		{
			get { return null; }
			set
			{
				_PopFirst = new UpdateBuilder();
				foreach (var name in value)
					if (name != null)
						_PopFirst.Combine(Update.PopFirst(name));
			}
		}
		UpdateBuilder _PopFirst;

		[Parameter]
		[ValidateNotNull]
		public string[] PopLast
		{
			get { return null; }
			set
			{
				_PopLast = new UpdateBuilder();
				foreach (var name in value)
					if (name != null)
						_PopLast.Combine(Update.PopLast(name));
			}
		}
		UpdateBuilder _PopLast;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] Pull
		{
			get { return null; }
			set
			{
				_Pull = new UpdateBuilder();
				foreach (var e in Convert(value, x => x))
				{
					BsonValue data = null;
					IMongoQuery query = null;
					if (e.Value == null)
					{
						data = BsonNull.Value;
					}
					else
					{
						query = PSObject.AsPSObject(e.Value).BaseObject as IMongoQuery;
						if (query == null)
							data = Actor.ToBsonValue(e.Value);
					}

					var n = e.Key;
					_Pull.Combine(query == null ? Update.Pull(n, data) : Update.Pull(n, query));
				}
			}
		}
		UpdateBuilder _Pull;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] PullAll
		{
			get { return null; }
			set
			{
				_PullAll = new UpdateBuilder();
				foreach (var e in Convert(value, Actor.ToEnumerableBsonValue))
					_PullAll.Combine(Update.PullAll(e.Key, e.Value));
			}
		}
		UpdateBuilder _PullAll;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] Push
		{
			get { return null; }
			set
			{
				_Push = new UpdateBuilder();
				foreach (var e in Convert(value, Actor.ToBsonValue))
					_Push.Combine(Update.Push(e.Key, e.Value));
			}
		}
		UpdateBuilder _Push;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] PushAll
		{
			get { return null; }
			set
			{
				_PushAll = new UpdateBuilder();
				foreach (var e in Convert(value, Actor.ToEnumerableBsonValue))
					_PushAll.Combine(Update.PushAll(e.Key, e.Value));
			}
		}
		UpdateBuilder _PushAll;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] Rename
		{
			get { return null; }
			set
			{
				_Rename = new UpdateBuilder();
				foreach (var e in Convert(value, x => x))
				{
					if (e.Value == null)
						throw new PSInvalidOperationException("New names must not be nulls.");

					_Rename.Combine(Update.Rename(e.Key, e.Value.ToString()));
				}
			}
		}
		UpdateBuilder _Rename;

		[Parameter(Position = 0)]
		[ValidateNotNull]
		public PSObject[] Set
		{
			get { return null; }
			set
			{
				_Set = new UpdateBuilder();
				foreach (var e in Convert(value, Actor.ToBsonValue))
					_Set.Combine(Update.Set(e.Key, e.Value));
			}
		}
		UpdateBuilder _Set;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] SetOnInsert
		{
			get { return null; }
			set
			{
				_SetOnInsert = new UpdateBuilder();
				foreach (var e in Convert(value, Actor.ToBsonValue))
					_SetOnInsert.Combine(Update.SetOnInsert(e.Key, e.Value));
			}
		}
		UpdateBuilder _SetOnInsert;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] Max
		{
			get { return null; }
			set
			{
				_Max = new UpdateBuilder();
				foreach (var e in Convert(value, Actor.ToBsonValue))
					_Max.Combine(Update.Max(e.Key, e.Value));
			}
		}
		UpdateBuilder _Max;

		[Parameter]
		[ValidateNotNull]
		public PSObject[] Min
		{
			get { return null; }
			set
			{
				_Min = new UpdateBuilder();
				foreach (var e in Convert(value, Actor.ToBsonValue))
					_Min.Combine(Update.Min(e.Key, e.Value));
			}
		}
		UpdateBuilder _Min;

		[Parameter]
		[ValidateNotNull]
		public string[] Unset
		{
			get { return null; }
			set
			{
				_Unset = new UpdateBuilder();
				foreach (var name in value)
					if (name != null)
						_Unset.Combine(Update.Unset(name));
			}
		}
		UpdateBuilder _Unset;

		[Parameter]
		[ValidateNotNull]
		public string[] CurrentDate
		{
			get { return null; }
			set
			{
				_CurrentDate = new UpdateBuilder();
				foreach (var name in value)
					if (name != null)
						_CurrentDate.Combine(Update.CurrentDate(name));
			}
		}
		UpdateBuilder _CurrentDate;

		static IEnumerable<KeyValuePair<string, T>> Convert<T>(PSObject[] values, Func<object, T> selector)
		{
			foreach (var po in values)
			{
				if (po == null)
					throw new PSInvalidOperationException("Null values are not allowed.");

				var dic = po.BaseObject as IDictionary;
				if (dic == null)
					throw new PSInvalidOperationException("Values must be dictionaries.");

				foreach (DictionaryEntry e in dic)
				{
					if (e.Key == null)
						throw new PSInvalidOperationException("Null keys are not allowed.");

					yield return new KeyValuePair<string, T>(e.Key.ToString(), selector(e.Value));
				}
			}
		}
		protected sealed override void BeginProcessing()
		{
			UpdateBuilder r = new UpdateBuilder();

			// 1.
			if (_Unset != null)
				r.Combine(_Unset);

			// 2.
			if (_Rename != null)
				r.Combine(_Rename);

			// 3.
			if (_Set != null)
				r.Combine(_Set);

			// 4.
			if (_SetOnInsert != null)
				r.Combine(_SetOnInsert);

			if (_Max != null)
				r.Combine(_Max);

			if (_Min != null)
				r.Combine(_Min);

			if (_BitwiseAnd != null)
				r.Combine(_BitwiseAnd);

			if (_BitwiseOr != null)
				r.Combine(_BitwiseOr);

			if (_BitwiseXor != null)
				r.Combine(_BitwiseXor);

			if (_Inc != null)
				r.Combine(_Inc);

			if (_Mul != null)
				r.Combine(_Mul);

			if (_CurrentDate != null)
				r.Combine(_CurrentDate);

			if (_AddToSet != null)
				r.Combine(_AddToSet);

			if (_AddToSetEach != null)
				r.Combine(_AddToSetEach);

			if (_PopFirst != null)
				r.Combine(_PopFirst);

			if (_PopLast != null)
				r.Combine(_PopLast);

			if (_Pull != null)
				r.Combine(_Pull);

			if (_PullAll != null)
				r.Combine(_PullAll);

			if (_Push != null)
				r.Combine(_Push);

			if (_PushAll != null)
				r.Combine(_PushAll);

			WriteObject(r);
		}
	}
}
