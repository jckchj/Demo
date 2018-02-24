using AzureAIDemo.Extensions;
using System;
using System.Collections.Generic;
using System.Globalization;
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

namespace AzureAIDemo
{
    public class SampleBindingConverter : IValueConverter
    {
        object IValueConverter.Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            Page s = value as Page;
            if (s != null)
            {
                return s.Title;
            }
            return null;
        }

        object IValueConverter.ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }

    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        public SubscriptionKeyPage SubscriptionPage { get; set; }

        public MainWindow()
        {
            InitializeComponent();
            SubscriptionPage = new SubscriptionKeyPage();
            _sampleFrame.Navigate(SubscriptionPage);

            _sampleListBox.ItemsSource = GetType().Assembly.GetTypes().Where(type => type.IsSubclassOf(typeof(SamplePage))
                && type.FullName.Contains(".Extensions.UI.")).Select(t => Activator.CreateInstance(t)).ToArray<object>();
        }

        private void ManageSubscriptionKey_Click(object sender, RoutedEventArgs e)
        {
            _sampleFrame.Navigate(SubscriptionPage);
            _sampleListBox.SelectedIndex = -1;
        }

        private void _sampleListBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            SamplePage scenario = _sampleListBox.SelectedItem as SamplePage;
            ClearLog();

            if (scenario != null)
            {
                scenario.DataContext = this.DataContext;
                _sampleFrame.Navigate(scenario);
            }
        }

        public void Log(string logMessage)
        {
            if (String.IsNullOrEmpty(logMessage) || logMessage == "\n")
            {
                _logTextBox.Text += "\n";
            }
            else
            {
                string timeStr = DateTime.Now.ToString("HH:mm:ss.ffffff");
                string messaage = "[" + timeStr + "]: " + logMessage + "\n";
                _logTextBox.Text += messaage;
            }
            _logTextBox.ScrollToEnd();
        }

        public void ClearLog()
        {
            _logTextBox.Text = "";
        }
    }
}
