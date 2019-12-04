
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Management.Automation;
using System.Reflection;
using System.Threading;

namespace Mdbc.Commands
{
	public abstract class AbstractSessionCommand : Abstract, IDisposable
	{
		bool _dispose;
		bool _disposed;
		IClientSessionHandle _Session;

		//! ThreadStatic and `= new Stack()` fails in Split-Pipeline
		[ThreadStatic]
		static Stack<IClientSessionHandle> _DefaultSessions_;
		static Stack<IClientSessionHandle> DefaultSessions { get { return _DefaultSessions_ ?? (_DefaultSessions_ = new Stack<IClientSessionHandle>()); } }
		internal static void PushDefaultSession(IClientSessionHandle session) { DefaultSessions.Push(session); }
		internal static IClientSessionHandle PopDefaultSession() { return DefaultSessions.Pop(); }

		//! #33 Do not use MongoClient.StartSession(), i.e. true session as implicit, some servers do not support sessions.
		//! For now follow the driver and hack its internal method.
		static MethodInfo _StartImplicitSession = typeof(MongoClient).GetMethod("StartImplicitSession", BindingFlags.NonPublic | BindingFlags.Instance, null, new Type[] { typeof(CancellationToken) }, null);
		IClientSessionHandle StartImplicitSession()
		{
			return (IClientSessionHandle)_StartImplicitSession.Invoke(MyClient, new object[] { default(CancellationToken) });
		}

		[Parameter]
		public IClientSessionHandle Session
		{
			get
			{
				if (_Session == null)
				{
					if (DefaultSessions.Count == 0)
					{
						// create implicit session
						_Session = StartImplicitSession();
						_dispose = true;
					}
					else
					{
						// use current default session
						_Session = DefaultSessions.Peek();
					}
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
