
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	public abstract class AbstractClientCommand : Abstract
	{
		MongoClient _Client;
		[Parameter]
		public MongoClient Client
		{
			get
			{
				if (_Client == null)
				{
					_Client = GetVariableValue(Actor.ClientVariable) as MongoClient;
					if (_Client == null) throw new PSInvalidOperationException("Specify a client by the parameter or variable Client.");
				}
				return _Client;
			}
			set
			{
				_Client = value;
			}
		}
	}
}
