using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;

public sealed class ScenesMenu : MonoBehaviour
{
    [SerializeField] private TMP_Text titleText;
    [SerializeField] private SceneButton backButton;
    [SerializeField] private SceneButton buttonPrefab;
    [SerializeField] private Transform buttonsContainer;
    [SerializeField] private string defaultTitle;
    [SerializeField] private string mainSceneName;
    [SerializeField] private SceneInfo[] scenes;

    private void Start()
    {
        SceneManager.LoadSceneAsync(mainSceneName);
        
        foreach (Transform child in buttonsContainer)
        {
            Destroy(child.gameObject);
        }
        
        backButton.Button.onClick.AddListener(ReturnToMainScene);
        
        foreach (var scene in scenes)
        {
            var sceneButton = Instantiate(buttonPrefab, buttonsContainer);
            sceneButton.Text.text = scene.SceneTitle;
            sceneButton.Button.onClick.AddListener(() => OpenScene(scene.SceneName));
        }

        backButton.gameObject.SetActive(false);
    }

    private void ReturnToMainScene()
    {
        titleText.text = defaultTitle;
        backButton.gameObject.SetActive(false);
        buttonsContainer.gameObject.SetActive(true);

        SceneManager.LoadSceneAsync(mainSceneName);
    }

    private void OpenScene(string sceneName)
    {
        titleText.text = sceneName;
        backButton.gameObject.SetActive(true);
        buttonsContainer.gameObject.SetActive(false);

        SceneManager.LoadSceneAsync(sceneName);
    }

    private static void UnloadActiveScene()
    {
        foreach (var obj in SceneManager.GetActiveScene().GetRootGameObjects())
        {
            Destroy(obj);
        }
    }
}