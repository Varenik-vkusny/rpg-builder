// Пример: как мир из RPG Builder попадает в игру на Unity.
// Файл мира (экспорт «Поделиться») читается через JsonUtility: классы ниже повторяют формат,
// ссылки между объектами — по slug. Тест в репозитории (test/unity_example_test.dart) краснеет,
// если поле появилось, пропало или сменило вид (число/строка/массив) либо сменилась версия —
// тогда этот файл надо обновить. Сам JsonUtility тест не запускает.
using System;
using System.Text;
using UnityEngine;

namespace RpgBuilder
{
    [Serializable] public class WorldInfo { public string slug, title, setting, tone; public int levelMin, levelMax; }

    [Serializable] public class PlaceData { public string slug, name, description, parent; public int levelMin, levelMax; }

    [Serializable] public class ItemData
    {
        public string slug, name, type, rarity, source, sourceRef, icon;
        public int level, damage, defense, price;
    }

    [Serializable] public class LootData { public string item; public float chance; }

    [Serializable] public class CharacterData
    {
        public string slug, name, description, role, location, icon, source, sourceRef, sourceCard;
        public int level, hp, attack;
        public LootData[] loot;
    }

    [Serializable] public class EnemyInEvent { public string enemy; public int amount; }

    [Serializable] public class ItemInEvent { public string item; public int amount; }

    [Serializable] public class EventData
    {
        public string slug, name, description, location;
        public EnemyInEvent[] enemies;
        public ItemInEvent[] items;
    }

    [Serializable] public class StepData { public string kind, target; public int amount; }

    [Serializable] public class RewardData { public string item; public int amount; }

    [Serializable] public class QuestData
    {
        public string slug, title, description, giver;
        public StepData[] steps;
        public RewardData[] rewards;
    }

    [Serializable] public class WorldFile
    {
        public int schemaVersion;
        public WorldInfo world;
        public PlaceData[] locations;
        public ItemData[] items;
        public CharacterData[] characters;
        public EventData[] events;
        public QuestData[] quests;
    }

    /// Повесьте на любой объект сцены и перетащите файл мира в поле «World Json».
    public class RpgBuilderWorldLoader : MonoBehaviour
    {
        public const int ExpectedSchemaVersion = 3;

        public TextAsset worldJson;
        string summary = "Перетащите файл мира в поле World Json";

        void Start()
        {
            if (worldJson != null) summary = Describe(worldJson.text);
            Debug.Log(summary);
        }

        void OnGUI() => GUI.Label(new Rect(20, 20, 900, 700), summary);

        /// Читает файл мира; null и сообщение в error, если версия формата другая.
        public static WorldFile Parse(string json, out string error)
        {
            error = null;
            var file = JsonUtility.FromJson<WorldFile>(json);
            if (file == null || file.schemaVersion != ExpectedSchemaVersion)
            {
                error = "Файл мира версии " + (file == null ? "?" : file.schemaVersion.ToString())
                    + ", а этот загрузчик ждёт версию " + ExpectedSchemaVersion
                    + ". Экспортируйте мир заново или обновите RpgBuilderWorld.cs.";
                return null;
            }
            return file;
        }

        /// Итог мира текстом: места, враги, квесты.
        public static string Describe(string json)
        {
            var w = Parse(json, out var error);
            if (w == null) return error;
            var sb = new StringBuilder();
            sb.AppendLine("Мир «" + w.world.title + "»: мест " + w.locations.Length
                + ", врагов " + CountRole(w, "enemy") + ", квестов " + w.quests.Length);
            sb.AppendLine("Места:");
            foreach (var p in w.locations) sb.AppendLine("  " + p.name + (p.parent == "" ? "" : " (в " + p.parent + ")"));
            sb.AppendLine("Враги:");
            foreach (var c in w.characters) if (c.role == "enemy") sb.AppendLine("  " + c.name + ", ур. " + c.level + ", " + c.hp + " HP, в " + c.location);
            sb.AppendLine("Квесты:");
            foreach (var q in w.quests) sb.AppendLine("  " + q.title + ": шагов " + q.steps.Length + ", выдаёт " + q.giver);
            return sb.ToString();
        }

        public static int CountRole(WorldFile w, string role)
        {
            int n = 0;
            foreach (var c in w.characters) if (c.role == role) n++;
            return n;
        }
    }
}
