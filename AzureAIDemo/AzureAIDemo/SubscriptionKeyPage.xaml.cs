//
// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license.
//
// Microsoft Cognitive Services (formerly Project Oxford): https://www.microsoft.com/cognitive-services
//
// Microsoft Cognitive Services (formerly Project Oxford) GitHub:
// https://github.com/Microsoft/Cognitive-Common-Windows
//
// Copyright (c) Microsoft Corporation
// All rights reserved.
//
// MIT License:
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED ""AS IS"", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

using System.ComponentModel;
using System.IO;
using System.IO.IsolatedStorage;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Controls;

namespace AzureAIDemo
{
    /// <summary>
    /// Interaction logic for SubscriptionKeyPage.xaml
    /// </summary>
    public partial class SubscriptionKeyPage : Page, INotifyPropertyChanged
    {
        private readonly string _isolatedStorageComputerVisionKeyFileName = "ComputerVisionKey.txt";
        private readonly string _isolatedStorageComputerVisionEndpointFileName = "ComputerVisionEndpoint.txt";
        private readonly string _isolatedStorageFaceKeyFileName = "FaceKey.txt";
        private readonly string _isolatedStorageFaceEndpointFileName = "FaceEndpoint.txt";

        private readonly string _defaultComputerVisionKeyPromptMessage = "Paste your computer vision API key here firstly";
        private readonly string _defaultComputerVisionEndpointPromptMessage = "Paste your computer vision endpoint here to start";
        private readonly string _defaultFaceKeyPromptMessage = "Paste your face API key here firstly";
        private readonly string _defaultFaceEndpointPromptMessage = "Paste your face endpoint here to start";

        private static string s_computerVisionyKey;
        private static string s_computerVisionEndpoint;
        private static string s_faceKey;
        private static string s_faceEndpoint;

        public SubscriptionKeyPage()
        {
            InitializeComponent();

            DataContext = this;
            ComputerVisionKey = GetSettingFromIsolatedStorage(_isolatedStorageComputerVisionKeyFileName, _defaultComputerVisionKeyPromptMessage);
            ComputerVisionEndpoint = GetSettingFromIsolatedStorage(_isolatedStorageComputerVisionEndpointFileName, _defaultComputerVisionEndpointPromptMessage);
            FaceKey = GetSettingFromIsolatedStorage(_isolatedStorageFaceKeyFileName, _defaultFaceKeyPromptMessage);
            FaceEndpoint = GetSettingFromIsolatedStorage(_isolatedStorageFaceEndpointFileName, _defaultFaceEndpointPromptMessage);
        }

        /// <summary>
        /// Gets or sets subscription key
        /// </summary>
        public string ComputerVisionKey
        {
            get
            {
                return s_computerVisionyKey;
            }

            set
            {
                s_computerVisionyKey = value;
                OnPropertyChanged<string>();
            }
        }

        /// <summary>
        /// Gets or sets subscription endpoint
        /// </summary>
        public string ComputerVisionEndpoint
        {
            get
            {
                return s_computerVisionEndpoint;
            }

            set
            {
                s_computerVisionEndpoint = value;
                OnPropertyChanged<string>();
            }
        }

        public string FaceKey
        {
            get
            {
                return s_faceKey;
            }

            set
            {
                s_faceKey = value;
                OnPropertyChanged<string>();
            }
        }

        /// <summary>
        /// Gets or sets subscription endpoint
        /// </summary>
        public string FaceEndpoint
        {
            get
            {
                return s_faceEndpoint;
            }

            set
            {
                s_faceEndpoint = value;
                OnPropertyChanged<string>();
            }
        }

        /// <summary>
        /// Implement INotifyPropertyChanged interface
        /// </summary>
        public event PropertyChangedEventHandler PropertyChanged;

        /// <summary>
        /// Helper function for INotifyPropertyChanged interface
        /// </summary>
        /// <typeparam name="T">Property type</typeparam>
        /// <param name="caller">Property name</param>
        private void OnPropertyChanged<T>([CallerMemberName]string caller = null)
        {
            if (PropertyChanged != null)
            {
                PropertyChanged(this, new PropertyChangedEventArgs(caller));
            }
        }

        private string GetSettingFromIsolatedStorage(string StorageFileName, string defaultValue)
        {
            string settingVal= null;

            using (IsolatedStorageFile isoStore = IsolatedStorageFile.GetStore(IsolatedStorageScope.User | IsolatedStorageScope.Assembly, null, null))
            {
                try
                {
                    using (var iStream = new IsolatedStorageFileStream(StorageFileName, FileMode.Open, isoStore))
                    {
                        using (var reader = new StreamReader(iStream))
                        {
                            settingVal = reader.ReadLine();
                        }
                    }
                }
                catch (FileNotFoundException)
                {
                    settingVal = null;
                }
            }
            if (string.IsNullOrEmpty(settingVal))
            {
                settingVal = defaultValue;
            }
            return settingVal;
        }

        private void SaveSubscriptionKeyToIsolatedStorage(string StorageFileName, string settingVal)
        {
            using (IsolatedStorageFile isoStore = IsolatedStorageFile.GetStore(IsolatedStorageScope.User | IsolatedStorageScope.Assembly, null, null))
            {
                using (var oStream = new IsolatedStorageFileStream(StorageFileName, FileMode.Create, isoStore))
                {
                    using (var writer = new StreamWriter(oStream))
                    {
                        writer.WriteLine(settingVal);
                    }
                }
            }
        }

        /// <summary>
        /// Handles the Click event of the saveSetting key save button.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">The <see cref="RoutedEventArgs"/> instance containing the event data.</param>
        private void SaveSetting_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                SaveSubscriptionKeyToIsolatedStorage(_isolatedStorageComputerVisionKeyFileName, ComputerVisionKey);
                SaveSubscriptionKeyToIsolatedStorage(_isolatedStorageComputerVisionEndpointFileName, ComputerVisionEndpoint);
                SaveSubscriptionKeyToIsolatedStorage(_isolatedStorageFaceKeyFileName, FaceKey);
                SaveSubscriptionKeyToIsolatedStorage(_isolatedStorageFaceEndpointFileName, FaceEndpoint);
                MessageBox.Show("Subscription key and endpoint are saved in your disk.\nYou do not need to paste the key next time.", "Subscription Setting");
            }
            catch (System.Exception exception)
            {
                MessageBox.Show("Fail to save subscription key & endpoint. Error message: " + exception.Message,
                    "Subscription Setting", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void DeleteSetting_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                ComputerVisionKey = _defaultComputerVisionKeyPromptMessage;
                ComputerVisionEndpoint = _defaultComputerVisionEndpointPromptMessage;
                FaceKey = _defaultFaceKeyPromptMessage;
                FaceEndpoint = _defaultFaceEndpointPromptMessage;
                SaveSubscriptionKeyToIsolatedStorage(_isolatedStorageComputerVisionKeyFileName, ComputerVisionKey);
                SaveSubscriptionKeyToIsolatedStorage(_isolatedStorageComputerVisionEndpointFileName, ComputerVisionEndpoint);
                SaveSubscriptionKeyToIsolatedStorage(_isolatedStorageFaceKeyFileName, FaceKey);
                SaveSubscriptionKeyToIsolatedStorage(_isolatedStorageFaceEndpointFileName, FaceEndpoint);
                MessageBox.Show("Subscription setting is deleted from your disk.", "Subscription Setting");
            }
            catch (System.Exception exception)
            {
                MessageBox.Show("Fail to delete subscription setting. Error message: " + exception.Message,
                    "Subscription Setting", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }
}
