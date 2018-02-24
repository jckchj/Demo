using AzureAIDemo.Extensions.Action;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace AzureAIDemo.Extensions.UI
{
    /// <summary>
    /// Interaction logic for VisionAPI.xaml
    /// </summary>
    public partial class VisionAPI : SamplePage
    {
        public VisionAPI()
        {
            InitializeComponent();

            _actions.ItemsSource = new DemoAction[]
            {
                new VisionAnalyzeAction(){
                    Title = "Analyze",
                    Key = mainWindow.SubscriptionPage.ComputerVisionKey,
                    EndPoint = mainWindow.SubscriptionPage.ComputerVisionEndpoint,
                },
                new VisionTagAction(){
                    Title = "Tag",
                    Key = mainWindow.SubscriptionPage.ComputerVisionKey,
                    EndPoint = mainWindow.SubscriptionPage.ComputerVisionEndpoint
                },
                new VisionLandmarksAction(){
                    Title = "Landmarks",
                    Key = mainWindow.SubscriptionPage.ComputerVisionKey,
                    EndPoint = mainWindow.SubscriptionPage.ComputerVisionEndpoint
                },
                new VisionCelebritiesAction(){
                    Title = "Celebrities",
                    Key = mainWindow.SubscriptionPage.ComputerVisionKey,
                    EndPoint = mainWindow.SubscriptionPage.ComputerVisionEndpoint
                },
                new VisionOCRAction(){
                    Title = "OCR",
                    Key = mainWindow.SubscriptionPage.ComputerVisionKey,
                    EndPoint = mainWindow.SubscriptionPage.ComputerVisionEndpoint
                },
                new FaceDetectAction(){
                    Title = "Face Detect",
                    Key = mainWindow.SubscriptionPage.FaceKey,
                    EndPoint = mainWindow.SubscriptionPage.FaceEndpoint
                }
            };
            ((DemoAction[])_actions.ItemsSource).ForEach(action => action.LogEvent += new Log(Log));
        }

        private void ShowImage(string imageFilePath)
        {
            Uri fileUri = new Uri(imageFilePath);

            // Show the image on the GUI
            BitmapImage bitmapSource = new BitmapImage();
            bitmapSource.BeginInit();
            bitmapSource.CacheOption = BitmapCacheOption.None;
            bitmapSource.UriSource = fileUri;
            bitmapSource.EndInit();

            _imagePreview.Source = bitmapSource;
            mainWindow.Log(imageFilePath);
        }

        private void _loadImage_Click(object sender, RoutedEventArgs e)
        {
            Microsoft.Win32.OpenFileDialog openDlg = new Microsoft.Win32.OpenFileDialog();
            openDlg.Filter = "Image Files(*.jpg, *.gif, *.bmp, *.png)|*.jpg;*.jpeg;*.gif;*.bmp;*.png";
            bool? result = openDlg.ShowDialog(Application.Current.MainWindow);

            if (!(bool)result)
            {
                return;
            }
            _imageInput.Text = openDlg.FileName;
            ShowImage(_imageInput.Text);
        }

        private void _imageInput_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_imageInput.SelectedIndex != -1)
            {
                ComboBoxItem cbi = (_imageInput.SelectedItem as ComboBoxItem);
                ShowImage(cbi.Content.ToString());
            }
        }

        private async void _apply_Click(object sender, RoutedEventArgs e)
        {
            if (_imagePreview.Source != null)
            {
                DemoAction action = _actions.SelectedItem as DemoAction;
                if (action != null)
                {
                    ClearLog();
                    _status.Text = "Start demo action " + action.Title +  "...";
                    try
                    {
                        string resp = await action.Act(_imageInput.Text);
                        Log(resp);
                    }
                    catch (Exception ex)
                    {
                        Log(ex.StackTrace);
                    }
                    _status.Text = "End demo action " + action.Title;
                }
            }
            else
            {
                Log("Please provide a valid image");
            }
        }
    }
}
