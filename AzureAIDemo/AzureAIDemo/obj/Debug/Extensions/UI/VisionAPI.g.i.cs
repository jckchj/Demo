﻿#pragma checksum "..\..\..\..\Extensions\UI\VisionAPI.xaml" "{ff1816ec-aa5e-4d10-87f7-6f4963833460}" "E89B9ACF9206ECABBA2C0D4B5393BA6C54EE3825"
//------------------------------------------------------------------------------
// <auto-generated>
//     This code was generated by a tool.
//     Runtime Version:4.0.30319.42000
//
//     Changes to this file may cause incorrect behavior and will be lost if
//     the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

using AzureAIDemo;
using System;
using System.Diagnostics;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Ink;
using System.Windows.Input;
using System.Windows.Markup;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Media.Media3D;
using System.Windows.Media.TextFormatting;
using System.Windows.Navigation;
using System.Windows.Shapes;
using System.Windows.Shell;


namespace AzureAIDemo.Extensions.UI {
    
    
    /// <summary>
    /// VisionAPI
    /// </summary>
    public partial class VisionAPI : AzureAIDemo.SamplePage, System.Windows.Markup.IComponentConnector {
        
        
        #line 22 "..\..\..\..\Extensions\UI\VisionAPI.xaml"
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Performance", "CA1823:AvoidUnusedPrivateFields")]
        internal System.Windows.Controls.ComboBox _imageInput;
        
        #line default
        #line hidden
        
        
        #line 35 "..\..\..\..\Extensions\UI\VisionAPI.xaml"
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Performance", "CA1823:AvoidUnusedPrivateFields")]
        internal System.Windows.Controls.Button _loadImage;
        
        #line default
        #line hidden
        
        
        #line 40 "..\..\..\..\Extensions\UI\VisionAPI.xaml"
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Performance", "CA1823:AvoidUnusedPrivateFields")]
        internal System.Windows.Controls.ComboBox _actions;
        
        #line default
        #line hidden
        
        
        #line 47 "..\..\..\..\Extensions\UI\VisionAPI.xaml"
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Performance", "CA1823:AvoidUnusedPrivateFields")]
        internal System.Windows.Controls.Button _apply;
        
        #line default
        #line hidden
        
        
        #line 49 "..\..\..\..\Extensions\UI\VisionAPI.xaml"
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Performance", "CA1823:AvoidUnusedPrivateFields")]
        internal System.Windows.Controls.TextBlock _status;
        
        #line default
        #line hidden
        
        
        #line 50 "..\..\..\..\Extensions\UI\VisionAPI.xaml"
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Performance", "CA1823:AvoidUnusedPrivateFields")]
        internal System.Windows.Controls.Image _imagePreview;
        
        #line default
        #line hidden
        
        private bool _contentLoaded;
        
        /// <summary>
        /// InitializeComponent
        /// </summary>
        [System.Diagnostics.DebuggerNonUserCodeAttribute()]
        [System.CodeDom.Compiler.GeneratedCodeAttribute("PresentationBuildTasks", "4.0.0.0")]
        public void InitializeComponent() {
            if (_contentLoaded) {
                return;
            }
            _contentLoaded = true;
            System.Uri resourceLocater = new System.Uri("/AzureAIDemo;component/extensions/ui/visionapi.xaml", System.UriKind.Relative);
            
            #line 1 "..\..\..\..\Extensions\UI\VisionAPI.xaml"
            System.Windows.Application.LoadComponent(this, resourceLocater);
            
            #line default
            #line hidden
        }
        
        [System.Diagnostics.DebuggerNonUserCodeAttribute()]
        [System.CodeDom.Compiler.GeneratedCodeAttribute("PresentationBuildTasks", "4.0.0.0")]
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Performance", "CA1811:AvoidUncalledPrivateCode")]
        internal System.Delegate _CreateDelegate(System.Type delegateType, string handler) {
            return System.Delegate.CreateDelegate(delegateType, this, handler);
        }
        
        [System.Diagnostics.DebuggerNonUserCodeAttribute()]
        [System.CodeDom.Compiler.GeneratedCodeAttribute("PresentationBuildTasks", "4.0.0.0")]
        [System.ComponentModel.EditorBrowsableAttribute(System.ComponentModel.EditorBrowsableState.Never)]
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Design", "CA1033:InterfaceMethodsShouldBeCallableByChildTypes")]
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Maintainability", "CA1502:AvoidExcessiveComplexity")]
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("Microsoft.Performance", "CA1800:DoNotCastUnnecessarily")]
        void System.Windows.Markup.IComponentConnector.Connect(int connectionId, object target) {
            switch (connectionId)
            {
            case 1:
            this._imageInput = ((System.Windows.Controls.ComboBox)(target));
            
            #line 22 "..\..\..\..\Extensions\UI\VisionAPI.xaml"
            this._imageInput.SelectionChanged += new System.Windows.Controls.SelectionChangedEventHandler(this._imageInput_SelectionChanged);
            
            #line default
            #line hidden
            return;
            case 2:
            this._loadImage = ((System.Windows.Controls.Button)(target));
            
            #line 35 "..\..\..\..\Extensions\UI\VisionAPI.xaml"
            this._loadImage.Click += new System.Windows.RoutedEventHandler(this._loadImage_Click);
            
            #line default
            #line hidden
            return;
            case 3:
            this._actions = ((System.Windows.Controls.ComboBox)(target));
            return;
            case 4:
            this._apply = ((System.Windows.Controls.Button)(target));
            
            #line 47 "..\..\..\..\Extensions\UI\VisionAPI.xaml"
            this._apply.Click += new System.Windows.RoutedEventHandler(this._apply_Click);
            
            #line default
            #line hidden
            return;
            case 5:
            this._status = ((System.Windows.Controls.TextBlock)(target));
            return;
            case 6:
            this._imagePreview = ((System.Windows.Controls.Image)(target));
            return;
            }
            this._contentLoaded = true;
        }
    }
}

