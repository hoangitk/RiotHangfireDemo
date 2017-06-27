﻿using System;
using System.Reflection;
using System.Web;
using System.Web.Mvc;
using System.Web.Routing;
using Hangfire;
using Microsoft.Owin;
using Owin;
using RiotHangfireDemo.Domain;
using RiotHangfireDemo.Web;
using SimpleInjector;
using SimpleInjector.Integration.Web;
using SimpleInjector.Integration.Web.Mvc;
using SimpleInjector.Lifestyles;

[assembly: OwinStartup(typeof(Startup))]

namespace RiotHangfireDemo.Web
{
    public class Startup
    {
        private static readonly Container Container = new Container();

        // Assemblies which should be scanned for types
        private static readonly Assembly[] AppAssemblies =
        {
            typeof(Startup).Assembly,
            typeof(DemoConfig).Assembly,
        };

        public static string Version { get; } = Guid.NewGuid().ToString("N"); //browser cachebuster

        // Called during OwinStartup phase
        public void Configuration(IAppBuilder app)
        {
            ConfigureSimpleInjector();
            ConfigureSettings();
            ConfigureRoutemeister();
            CongigureEntityFramework();
            ConfigureMvc(RouteTable.Routes);
            ConfigureHangfire(app);
            ConfigureSignalr(app);

            Container.Verify();

            Commander.Initialize(AppAssemblies);
        }

        private static void ConfigureSimpleInjector()
        {
            // If there is no HttpContext present, we are running in a Hangfire background job.
            Container.Options.DefaultScopedLifestyle = Lifestyle.CreateHybrid(() => HttpContext.Current == null,
                new ThreadScopedLifestyle(),
                new WebRequestLifestyle()
            );

            // Automatically register any interface with only a single implementation
            var services = AppAssemblies.GetInterfacesWithSingleImplementation();
            foreach (var service in services)
            {
                Container.Register(service.Key, service.Value, Lifestyle.Scoped);
            }

            Container.Register<IDb, DemoDb>(Lifestyle.Scoped); //Domain InternalsVisibleTo

            Container.RegisterMvcControllers(AppAssemblies);
        }

        private static void ConfigureSettings()
        {
            // Put strongly-typed configuration classes in the container for injection
            var config = Ext.MapAppSettingsToClass<DemoConfig>();
            Container.RegisterSingleton(config);
        }

        private static void ConfigureRoutemeister()
        {
            // Register all Command Handlers
            var requestType = typeof(IRequestHandler<,>);
            Container.Register(requestType, AppAssemblies);

            var factory = new Routemeister.MessageRouteFactory();
            var routes = new Routemeister.MessageRoutes
            {
                factory.Create(AppAssemblies, requestType),
            };
            var dispatcher = new Dispatcher((t, e) => Container.GetInstance(t), routes);

            Container.RegisterSingleton(() => dispatcher);
        }

        private static void CongigureEntityFramework()
        {
            var db = Container.GetInstance<IDb>();
            db.CreateDatabase(); // ignored if exists
        }

        private static void ConfigureMvc(RouteCollection routes)
        {
            AreaRegistration.RegisterAllAreas();

            routes.IgnoreRoute("{resource}.axd/{*pathInfo}");
            routes.MapMvcAttributeRoutes();
            routes.MapRoute(
                name: "Default",
                url: "{controller}/{action}/{id}",
                defaults: new { controller = "Home", action = "Index", id = UrlParameter.Optional }
            );

            DependencyResolver.SetResolver(new SimpleInjectorDependencyResolver(Container));
        }

        private static void ConfigureHangfire(IAppBuilder app)
        {
            var config = Container.GetInstance<DemoConfig>();

            //REF: http://docs.hangfire.io/en/latest/quick-start.html
            GlobalConfiguration.Configuration
                .UseSqlServerStorage(nameof(DemoDb))
                .UseActivator(new SimpleInjectorJobActivator(Container, Lifestyle.Scoped))
                .UseFilter(new HangfireJobPusher(Container.GetInstance<IPusher>()))
                .UseFilter(new AutomaticRetryAttribute { Attempts = 1 });

            app.UseHangfireServer(new BackgroundJobServerOptions
            {
                ServerName = Environment.MachineName,
                WorkerCount = config.HangfireWorkerCount,
            });

            app.UseHangfireDashboard("/hangfire", new DashboardOptions());
        }

        private static void ConfigureSignalr(IAppBuilder app)
        {
            app.MapSignalR();
        }
    };
}