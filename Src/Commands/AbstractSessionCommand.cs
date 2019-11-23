
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Management.Automation;

namespace Mdbc.Commands
{
	public abstract class AbstractSessionCommand : Abstract, IDisposable
	{
		bool _dispose;
		bool _disposed;
		IClientSessionHandle _Session;

		[Parameter]
		public IClientSessionHandle Session
		{
			get
			{
				if (_Session == null)
				{
					_Session = MyClient.StartSession();
					_dispose = true;
				}
				return _Session;
			}
			set
			{
				if (_Session != null)
					throw new InvalidOperationException("Session cannot be set twice.");

				_Session = value;
			}
		}

		protected abstract IMongoClient MyClient { get; }

		public void Dispose()
		{
			Dispose(true);
			GC.SuppressFinalize(this);
		}

		protected virtual void Dispose(bool disposing)
		{
			if (_disposed)
				return;

			if (disposing && _dispose)
				_Session.Dispose();

			_disposed = true;
		}
	}
}
